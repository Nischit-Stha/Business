-- Customer self-service portal. Customer access is deny-by-default and identity-linked.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED','MAINTENANCE_RECORD_CREATED','MAINTENANCE_RECORD_STATUS_CHANGED','MAINTENANCE_RECORD_COMPLETED','SERVICE_INTERVAL_CHANGED','COMPLIANCE_ATTENTION_REFRESHED','NOTIFICATION_CREATED','NOTIFICATION_CANCELLED','NOTIFICATION_RETRIED','NOTIFICATION_CLAIMED','NOTIFICATION_STATUS_CHANGED','NOTIFICATION_MANUALLY_QUEUED',
  'CUSTOMER_PORTAL_ISSUE_SUBMITTED','CUSTOMER_PORTAL_RESCHEDULE_REQUESTED','CUSTOMER_PORTAL_PROFILE_CHANGE_REQUESTED','CUSTOMER_PORTAL_ACCESS_CHANGED'
));

create table public.customer_portal_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  customer_id uuid not null unique references public.customers(id) on delete cascade,
  status text not null default 'ACTIVE' check(status in ('ACTIVE','DISABLED')),
  created_by uuid references public.staff_profiles(user_id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create trigger customer_portal_accounts_touch before update on public.customer_portal_accounts for each row execute function app_private.touch_updated_at();

create or replace function app_private.portal_customer_id() returns uuid language sql stable security definer set search_path='' as $$
  select customer_id from public.customer_portal_accounts where user_id=auth.uid() and status='ACTIVE'
$$;
revoke all on function app_private.portal_customer_id() from public;
grant execute on function app_private.portal_customer_id() to authenticated;

alter table public.vehicle_issues alter column created_by drop not null;
alter table public.vehicle_issues add column source text not null default 'STAFF' check(source in ('STAFF','CUSTOMER_PORTAL')),
  add column reporter_auth_user uuid references auth.users(id),
  add constraint vehicle_issue_creator_source check((source='STAFF' and created_by is not null and reporter_auth_user is null) or (source='CUSTOMER_PORTAL' and created_by is null and reporter_auth_user is not null));
alter table public.vehicle_issue_events alter column actor drop not null;

create table public.customer_portal_requests (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id),
  request_type text not null check(request_type in ('PICKUP_RESCHEDULE','RETURN_RESCHEDULE','PROFILE_CONTACT_CHANGE')),
  pickup_id uuid references public.pickup_checklists(id), return_id uuid references public.return_checklists(id),
  requested_for timestamptz, requested_phone text, requested_email text,
  customer_note text check(customer_note is null or length(customer_note)<=500),
  status text not null default 'OPEN' check(status in ('OPEN','IN_REVIEW','APPROVED','DECLINED','COMPLETED','CANCELLED')),
  source text not null default 'CUSTOMER_PORTAL' check(source='CUSTOMER_PORTAL'),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check((request_type='PICKUP_RESCHEDULE' and pickup_id is not null and return_id is null and requested_for is not null) or
        (request_type='RETURN_RESCHEDULE' and return_id is not null and pickup_id is null and requested_for is not null) or
        (request_type='PROFILE_CONTACT_CHANGE' and pickup_id is null and return_id is null and (requested_phone is not null or requested_email is not null)))
);
create index customer_portal_requests_staff_queue on public.customer_portal_requests(status,created_at) where status in ('OPEN','IN_REVIEW');
create trigger customer_portal_requests_touch before update on public.customer_portal_requests for each row execute function app_private.touch_updated_at();

create table public.business_payment_settings (
  id boolean primary key default true check(id), payid_instructions text check(length(payid_instructions)<=500),
  customer_display_approved boolean not null default false, updated_by uuid references public.staff_profiles(user_id), updated_at timestamptz not null default now(),
  check(not customer_display_approved or btrim(coalesce(payid_instructions,''))<>'')
);
insert into public.business_payment_settings(id) values(true);

-- Base operational tables remain staff-only. Customers can only select the filtered projections below.
create policy customer_own_portal_account on public.customer_portal_accounts for select to authenticated using(user_id=auth.uid() and status='ACTIVE');
create policy customer_own_requests on public.customer_portal_requests for select to authenticated using(customer_id=app_private.portal_customer_id());
create policy staff_read_portal_accounts on public.customer_portal_accounts for select to authenticated using(app_private.is_staff());
create policy staff_read_portal_requests on public.customer_portal_requests for select to authenticated using(app_private.is_staff());

alter table public.customer_portal_accounts enable row level security; alter table public.customer_portal_requests enable row level security; alter table public.business_payment_settings enable row level security;
create policy staff_read_payment_settings on public.business_payment_settings for select to authenticated using(app_private.is_staff());
revoke all on public.customer_portal_accounts,public.customer_portal_requests,public.business_payment_settings from anon,authenticated;
grant select on public.customer_portal_accounts,public.customer_portal_requests to authenticated;

-- Owner-evaluated projections deliberately bypass base-table staff RLS, but every row is constrained
-- by the authenticated user's active portal link and every column is explicitly customer-safe.
create view public.portal_profile with (security_barrier=true) as select id customer_id,full_name,phone,email,licence_expiry,status from public.customers where id=app_private.portal_customer_id();
create view public.portal_agreements with (security_barrier=true) as
select a.id,a.agreement_type,a.status,a.start_date,a.end_date,a.weekly_amount,a.deposit_amount,a.agreed_total_amount,a.agreed_payment_count,a.vehicle_id,v.registration,v.make,v.model,
 (select count(*) from public.payment_schedule_items s where s.agreement_id=a.id and s.status='PAID') payments_completed,
 (select coalesce(sum(s.amount_due-s.amount_paid),0) from public.payment_schedule_items s where s.agreement_id=a.id and s.status not in ('PAID','WAIVED')) remaining_balance,
 (select count(*) from public.payment_schedule_items s where s.agreement_id=a.id and s.status not in ('PAID','WAIVED')) remaining_scheduled_payments
from public.agreements a left join public.vehicles v on v.id=a.vehicle_id where a.customer_id=app_private.portal_customer_id();
create view public.portal_payment_schedule with (security_barrier=true) as select s.id,s.agreement_id,s.due_date,s.amount_due,s.amount_paid,s.status,s.paid_at from public.payment_schedule_items s join public.agreements a on a.id=s.agreement_id where a.customer_id=app_private.portal_customer_id();
create view public.portal_payment_receipts with (security_barrier=true) as
select t.id,t.agreement_id,t.received_at,t.amount,'Payment received'::text customer_reference,v.registration,case when t.transaction_type='RECEIPT' then 'RECEIVED' else 'CORRECTION' end status
from public.payment_transactions t join public.agreements a on a.id=t.agreement_id left join public.vehicles v on v.id=a.vehicle_id where a.customer_id=app_private.portal_customer_id();
create view public.portal_maintenance with (security_barrier=true) as
select v.id vehicle_id,v.registration,v.make,v.model,v.odometer,s.status,s.last_service_date,s.next_service_odometer,s.km_remaining,
 (select min(r.scheduled_for) from public.maintenance_service_records r where r.vehicle_id=v.id and r.status='SCHEDULED' and r.scheduled_for>=current_date) scheduled_service_date
from public.vehicle_assignments a join public.vehicles v on v.id=a.vehicle_id left join public.vehicle_maintenance_status s on s.vehicle_id=v.id where a.customer_id=app_private.portal_customer_id() and a.assignment_status='ACTIVE';
create view public.portal_documents with (security_barrier=true) as select id,document_type,status,expiry_date,created_at,created_at updated_at from public.customer_documents where customer_id=app_private.portal_customer_id();
create view public.portal_notifications with (security_barrier=true) as select id,created_at,type,channel,status from public.notifications where customer_id=app_private.portal_customer_id() and channel<>'INTERNAL';
create view public.portal_issues with (security_barrier=true) as select id,vehicle_id,agreement_id,category,severity,created_at,updated_at,
 case status when 'OPEN' then 'REPORTED' when 'ASSIGNED' then 'BEING_REVIEWED' when 'IN_PROGRESS' then 'IN_PROGRESS' when 'WAITING_CUSTOMER' then 'WAITING' when 'WAITING_PARTS' then 'WAITING' when 'RESOLVED' then 'RESOLVED' when 'CANCELLED' then 'RESOLVED' end customer_status,
 case when source='CUSTOMER_PORTAL' then description else null end customer_description
from public.vehicle_issues where customer_id=app_private.portal_customer_id();
create view public.portal_pickups with (security_barrier=true) as select p.id,p.agreement_id,p.vehicle_id,p.scheduled_at,p.actual_at,p.status,v.registration from public.pickup_checklists p join public.vehicles v on v.id=p.vehicle_id where p.customer_id=app_private.portal_customer_id();
create view public.portal_returns with (security_barrier=true) as select r.id,r.scheduled_at,r.actual_at,r.status,a.vehicle_id,v.registration from public.return_checklists r join public.vehicle_assignments a on a.id=r.assignment_id join public.vehicles v on v.id=a.vehicle_id where a.customer_id=app_private.portal_customer_id();
create view public.portal_payment_instructions with (security_barrier=true) as select payid_instructions from public.business_payment_settings where id and customer_display_approved;

grant select on public.portal_profile,public.portal_agreements,public.portal_payment_schedule,public.portal_payment_receipts,public.portal_maintenance,public.portal_documents,public.portal_notifications,public.portal_issues,public.portal_pickups,public.portal_returns,public.portal_payment_instructions to authenticated;
grant select on public.business_payment_settings to authenticated;

create or replace function public.set_customer_portal_access(p_user_id uuid,p_customer_id uuid,p_enabled boolean) returns public.customer_portal_accounts language plpgsql security definer set search_path='' as $$
declare r public.customer_portal_accounts;
begin if not exists(select 1 from public.staff_profiles s where s.user_id=auth.uid() and s.role='ADMIN' and s.status='ACTIVE' and s.is_active) then raise exception 'administrator access required' using errcode='42501'; end if;
 if not exists(select 1 from auth.users u where u.id=p_user_id) then raise exception 'authentication user not found'; end if; if not exists(select 1 from public.customers c where c.id=p_customer_id) then raise exception 'customer not found'; end if;
 insert into public.customer_portal_accounts(user_id,customer_id,status,created_by) values(p_user_id,p_customer_id,case when p_enabled then 'ACTIVE' else 'DISABLED' end,auth.uid())
 on conflict(user_id) do update set customer_id=excluded.customer_id,status=excluded.status,created_by=excluded.created_by returning * into r;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'CUSTOMER_PORTAL_ACCESS_CHANGED','customer',p_customer_id,jsonb_build_object('portal_user_id',p_user_id,'enabled',p_enabled)); return r; end $$;

create or replace function public.submit_customer_portal_issue(p_category text,p_description text,p_severity text,p_note text default null) returns uuid language plpgsql security definer set search_path='' as $$
declare cid uuid; a public.vehicle_assignments; ag public.agreements; i public.vehicle_issues; detail text;
begin cid:=app_private.portal_customer_id(); if cid is null then raise exception 'active customer portal access required' using errcode='42501'; end if;
 if p_category not in ('WARNING_LIGHT','BREAKDOWN','TYRE','BATTERY','DAMAGE','PARKING','ACCIDENT','SERVICE','OTHER') then raise exception 'invalid issue category' using errcode='22023'; end if;
 if p_severity not in ('LOW','MEDIUM','HIGH','CRITICAL') then raise exception 'invalid customer severity' using errcode='22023'; end if;
 detail:=btrim(coalesce(p_description,'')); if detail='' or length(detail)>500 then raise exception 'description must be between 1 and 500 characters' using errcode='22023'; end if;
 if p_note is not null and length(btrim(p_note))>500 then raise exception 'note is too long' using errcode='22023'; end if;
 select * into a from public.vehicle_assignments where customer_id=cid and assignment_status='ACTIVE' order by assigned_at desc limit 1; if not found then raise exception 'no active assigned vehicle'; end if;
 select * into ag from public.agreements where customer_id=cid and vehicle_id=a.vehicle_id and status in ('ACTIVE','SUSPENDED') order by created_at desc limit 1;
 if nullif(btrim(coalesce(p_note,'')),'') is not null then detail:=detail||E'\nCustomer note: '||btrim(p_note); end if;
 insert into public.vehicle_issues(vehicle_id,customer_id,agreement_id,created_by,severity,category,description,status,source,reporter_auth_user)
 values(a.vehicle_id,cid,ag.id,null,p_severity,p_category,detail,'OPEN','CUSTOMER_PORTAL',auth.uid()) returning * into i;
 insert into public.vehicle_issue_events(vehicle_issue_id,actor,event_type,to_status,metadata) values(i.id,null,'CREATED','OPEN',jsonb_build_object('source','CUSTOMER_PORTAL'));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'CUSTOMER_PORTAL_ISSUE_SUBMITTED','vehicle_issue',i.id,jsonb_build_object('vehicle_id',i.vehicle_id,'category',i.category,'severity',i.severity,'source','CUSTOMER_PORTAL'));
 if i.severity in ('HIGH','CRITICAL') or i.category in ('BREAKDOWN','ACCIDENT','PARKING') then perform app_private.upsert_exception('VEHICLE_ISSUE',case when i.category in ('BREAKDOWN','ACCIDENT') and i.severity='HIGH' then 'CRITICAL' else i.severity end,'vehicle_issue',i.id,'vehicle-issue:'||i.id,initcap(replace(i.category,'_',' '))||' reported through customer portal',jsonb_build_object('vehicle_id',i.vehicle_id,'source','CUSTOMER_PORTAL'),i.severity in ('HIGH','CRITICAL'),auth.uid()); end if;
 perform app_private.sync_vehicle_issue_state(i.vehicle_id); return i.id; end $$;

create or replace function public.request_portal_reschedule(p_kind text,p_schedule_id uuid,p_requested_for timestamptz,p_note text default null) returns public.customer_portal_requests language plpgsql security definer set search_path='' as $$
declare cid uuid; r public.customer_portal_requests;
begin cid:=app_private.portal_customer_id(); if cid is null then raise exception 'active customer portal access required' using errcode='42501'; end if; if p_requested_for<=now() then raise exception 'requested time must be in the future'; end if;
 if p_kind='PICKUP' then if not exists(select 1 from public.pickup_checklists p where p.id=p_schedule_id and p.customer_id=cid and p.status not in ('COMPLETED','CANCELLED')) then raise exception 'active pickup not found'; end if; insert into public.customer_portal_requests(customer_id,request_type,pickup_id,requested_for,customer_note,created_by) values(cid,'PICKUP_RESCHEDULE',p_schedule_id,p_requested_for,nullif(btrim(p_note),''),auth.uid()) returning * into r;
 elsif p_kind='RETURN' then if not exists(select 1 from public.return_checklists q join public.vehicle_assignments a on a.id=q.assignment_id where q.id=p_schedule_id and a.customer_id=cid and q.status not in ('COMPLETED','CANCELLED')) then raise exception 'active return not found'; end if; insert into public.customer_portal_requests(customer_id,request_type,return_id,requested_for,customer_note,created_by) values(cid,'RETURN_RESCHEDULE',p_schedule_id,p_requested_for,nullif(btrim(p_note),''),auth.uid()) returning * into r;
 else raise exception 'invalid schedule kind'; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'CUSTOMER_PORTAL_RESCHEDULE_REQUESTED','customer_portal_request',r.id,jsonb_build_object('request_type',r.request_type)); return r; end $$;

create or replace function public.request_portal_contact_change(p_phone text default null,p_email text default null,p_note text default null) returns public.customer_portal_requests language plpgsql security definer set search_path='' as $$
declare cid uuid; r public.customer_portal_requests;
begin cid:=app_private.portal_customer_id(); if cid is null then raise exception 'active customer portal access required' using errcode='42501'; end if;
 if nullif(btrim(coalesce(p_phone,'')),'') is null and nullif(btrim(coalesce(p_email,'')),'') is null then raise exception 'phone or email is required'; end if;
 if p_phone is not null and length(btrim(p_phone))>40 then raise exception 'phone is too long'; end if; if p_email is not null and (length(btrim(p_email))>254 or btrim(p_email) !~* '^[^@[:space:]]+@[^@[:space:]]+$') then raise exception 'invalid email'; end if;
 insert into public.customer_portal_requests(customer_id,request_type,requested_phone,requested_email,customer_note,created_by) values(cid,'PROFILE_CONTACT_CHANGE',nullif(btrim(p_phone),''),nullif(btrim(p_email),''),nullif(btrim(p_note),''),auth.uid()) returning * into r;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'CUSTOMER_PORTAL_PROFILE_CHANGE_REQUESTED','customer_portal_request',r.id,jsonb_build_object('phone_requested',r.requested_phone is not null,'email_requested',r.requested_email is not null)); return r; end $$;

revoke all on function public.set_customer_portal_access(uuid,uuid,boolean),public.submit_customer_portal_issue(text,text,text,text),public.request_portal_reschedule(text,uuid,timestamptz,text),public.request_portal_contact_change(text,text,text) from public;
grant execute on function public.set_customer_portal_access(uuid,uuid,boolean),public.submit_customer_portal_issue(text,text,text,text),public.request_portal_reschedule(text,uuid,timestamptz,text),public.request_portal_contact_change(text,text,text) to authenticated;
