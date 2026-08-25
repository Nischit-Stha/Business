-- Trial-readiness account lifecycle, security audit, and scheduler hardening.
-- Supabase Auth owns password and recovery tokens; raw tokens are never persisted here.

create table public.account_invitations (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  email text not null check (email = lower(email) and length(email) between 3 and 320),
  account_type text not null check (account_type in ('STAFF','CUSTOMER')),
  customer_id uuid references public.customers(id),
  staff_role text check (staff_role in ('ADMIN','STAFF')),
  status text not null default 'PENDING' check (status in ('PENDING','ACCEPTED','EXPIRED','REVOKED','SUPERSEDED')),
  expires_at timestamptz not null,
  sent_at timestamptz not null default now(),
  accepted_at timestamptz,
  revoked_at timestamptz,
  resend_count integer not null default 0 check (resend_count between 0 and 20),
  created_by uuid not null references public.staff_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((account_type='STAFF' and customer_id is null and staff_role is not null) or
         (account_type='CUSTOMER' and customer_id is not null and staff_role is null))
);
create unique index account_invitations_one_pending_user on public.account_invitations(auth_user_id) where status='PENDING';
create index account_invitations_expiry on public.account_invitations(expires_at) where status='PENDING';
create trigger account_invitations_touch before update on public.account_invitations for each row execute function app_private.touch_updated_at();

create table public.account_security_events (
  id bigint generated always as identity primary key,
  actor uuid references auth.users(id),
  subject_user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('INVITATION_CREATED','INVITATION_RESENT','INVITATION_ACCEPTED','INVITATION_REVOKED','INVITATION_EXPIRED','PASSWORD_RECOVERY_REQUESTED','PASSWORD_CHANGED','ACCOUNT_DISABLED','ACCOUNT_ENABLED','SESSIONS_REVOKED','REAUTHENTICATION_REQUIRED','MFA_ENROLLED','MFA_REMOVED')),
  occurred_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context)='object')
);
create index account_security_events_subject on public.account_security_events(subject_user_id,occurred_at desc);
create trigger account_security_events_immutable before update or delete on public.account_security_events for each row execute function app_private.immutable_operational_history();

alter table public.account_invitations enable row level security;
alter table public.account_security_events enable row level security;
create policy admin_read_account_invitations on public.account_invitations for select to authenticated using(app_private.is_admin());
create policy admin_read_account_security_events on public.account_security_events for select to authenticated using(app_private.is_admin());
revoke all on public.account_invitations,public.account_security_events from anon,authenticated;
grant select on public.account_invitations,public.account_security_events to authenticated;

create or replace function public.record_invitation_created(p_auth_user_id uuid,p_email text,p_account_type text,p_customer_id uuid,p_staff_role text,p_expires_at timestamptz)
returns public.account_invitations language plpgsql security definer set search_path='' as $$
declare r public.account_invitations;
begin
 if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501'; end if;
 update public.account_invitations set status='SUPERSEDED' where auth_user_id=p_auth_user_id and status='PENDING';
 insert into public.account_invitations(auth_user_id,email,account_type,customer_id,staff_role,expires_at,created_by)
 values(p_auth_user_id,lower(btrim(p_email)),p_account_type,p_customer_id,p_staff_role,p_expires_at,auth.uid()) returning * into r;
 insert into public.account_security_events(actor,subject_user_id,event_type,context) values(auth.uid(),p_auth_user_id,'INVITATION_CREATED',jsonb_build_object('invitation_id',r.id,'account_type',p_account_type));
 return r;
end $$;

create or replace function public.record_invitation_resent(p_invitation_id uuid,p_expires_at timestamptz)
returns public.account_invitations language plpgsql security definer set search_path='' as $$
declare r public.account_invitations;
begin
 if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501'; end if;
 update public.account_invitations set expires_at=p_expires_at,sent_at=now(),resend_count=resend_count+1,status='PENDING' where id=p_invitation_id and status in ('PENDING','EXPIRED') and resend_count<20 returning * into r;
 if not found then raise exception 'invitation cannot be resent'; end if;
 insert into public.account_security_events(actor,subject_user_id,event_type,context) values(auth.uid(),r.auth_user_id,'INVITATION_RESENT',jsonb_build_object('invitation_id',r.id,'resend_count',r.resend_count)); return r;
end $$;

create or replace function public.expire_account_invitations() returns integer language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 if auth.role()<>'service_role' and not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 with expired as (update public.account_invitations set status='EXPIRED' where status='PENDING' and expires_at<=now() returning auth_user_id)
 insert into public.account_security_events(subject_user_id,event_type,context) select auth_user_id,'INVITATION_EXPIRED','{}'::jsonb from expired;
 get diagnostics n=row_count; return n;
end $$;

create or replace function public.accept_current_invitation() returns void language plpgsql security definer set search_path='' as $$
declare r public.account_invitations;
begin
 select * into r from public.account_invitations where auth_user_id=auth.uid() and status='PENDING' and expires_at>now() for update;
 if not found then raise exception 'active invitation not found'; end if;
 update public.account_invitations set status='ACCEPTED',accepted_at=now() where id=r.id;
 insert into public.account_security_events(actor,subject_user_id,event_type,context) values(auth.uid(),auth.uid(),'INVITATION_ACCEPTED',jsonb_build_object('invitation_id',r.id));
end $$;

revoke all on function public.record_invitation_created(uuid,text,text,uuid,text,timestamptz),public.record_invitation_resent(uuid,timestamptz),public.expire_account_invitations(),public.accept_current_invitation() from public;
grant execute on function public.record_invitation_created(uuid,text,text,uuid,text,timestamptz),public.record_invitation_resent(uuid,timestamptz),public.expire_account_invitations() to authenticated;
grant execute on function public.expire_account_invitations() to service_role;
grant execute on function public.accept_current_invitation() to authenticated;

-- Job-level time budgets are enforced by PostgreSQL statement_timeout in the scheduler transaction.
alter table public.scheduled_jobs add column timeout_seconds integer not null default 120 check(timeout_seconds between 5 and 300);
alter table public.scheduled_job_executions add column request_id text check(request_id is null or length(request_id)<=100);

create or replace function public.run_due_scheduled_jobs_scheduler(p_actor uuid,p_limit integer default 8)
returns setof public.scheduled_job_executions language plpgsql security definer set search_path='' as $$
begin
 if auth.role()<>'service_role' then raise exception 'service role required' using errcode='42501'; end if;
 if not exists(select 1 from public.staff_profiles where user_id=p_actor and role='ADMIN' and status='ACTIVE' and is_active) then raise exception 'active scheduler administrator required'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);
 perform set_config('statement_timeout','300000',true);
 return query select * from public.run_due_scheduled_jobs(p_limit);
end $$;
revoke all on function public.run_due_scheduled_jobs_scheduler(uuid,integer) from public,anon,authenticated;
grant execute on function public.run_due_scheduled_jobs_scheduler(uuid,integer) to service_role;

create or replace function public.record_provider_delivery_receipt(p_provider_message_id text)
returns uuid language plpgsql security definer set search_path='' as $$
declare n public.notifications;
begin
 if auth.role()<>'service_role' then raise exception 'service role required' using errcode='42501'; end if;
 update public.notifications set status='DELIVERED',delivered_at=now() where provider_message_id=p_provider_message_id and status in ('SENT','DELIVERED') returning * into n;
 if not found then raise exception 'matching sent notification not found'; end if;
 return n.id;
end $$;
revoke all on function public.record_provider_delivery_receipt(text) from public,anon,authenticated;
grant execute on function public.record_provider_delivery_receipt(text) to service_role;

comment on table public.account_invitations is 'Metadata only. Supabase Auth owns and expires raw invite/recovery tokens.';
comment on table public.account_security_events is 'Immutable, deliberately low-detail account security audit. Never store tokens, passwords, IP addresses, or raw provider responses.';
