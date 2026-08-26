-- Privacy-conscious security telemetry and application abuse boundary.
-- Never put credentials, tokens, raw request bodies, document contents, licence data,
-- bank references, IP addresses, email addresses, or provider responses in context.

create table public.security_events (
  id bigint generated always as identity primary key,
  actor uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in (
    'AUTHORIZATION_DENIED','INVITATION_FAILURE','INVITATION_MISUSE','UPLOAD_REJECTED',
    'WEBHOOK_VERIFICATION_FAILURE','SCHEDULER_AUTH_FAILURE','NOTIFICATION_FAILURE_THRESHOLD',
    'RATE_LIMIT_EXCEEDED','ADMIN_MFA_CHANGED'
  )),
  occurred_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context)='object' and pg_column_size(context)<=2048)
);
create index security_events_type_time on public.security_events(event_type,occurred_at desc);
create trigger security_events_immutable before update or delete on public.security_events for each row execute function app_private.immutable_operational_history();
alter table public.security_events enable row level security;
revoke all on public.security_events from anon,authenticated;
grant select on public.security_events to authenticated;
create policy admin_read_security_events on public.security_events for select to authenticated using(app_private.is_admin());

create table app_private.abuse_counters (
  actor uuid not null references auth.users(id) on delete cascade,
  action text not null check(length(action) between 1 and 64),
  window_started_at timestamptz not null,
  attempts integer not null check(attempts>0),
  primary key(actor,action)
);

create or replace function public.consume_action_budget(p_action text,p_limit integer,p_window_seconds integer)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_counter app_private.abuse_counters;
begin
 if v_actor is null then raise exception 'authentication required' using errcode='42501'; end if;
 if p_action not in ('INVITATION','PORTAL_ISSUE','PORTAL_REQUEST','DOCUMENT_UPLOAD','NOTIFICATION_TRIGGER')
   or p_limit not between 1 and 100 or p_window_seconds not between 60 and 86400 then
   raise exception 'invalid abuse-control policy' using errcode='22023';
 end if;
 insert into app_private.abuse_counters(actor,action,window_started_at,attempts) values(v_actor,p_action,now(),1)
 on conflict(actor,action) do update set
  window_started_at=case when app_private.abuse_counters.window_started_at <= now()-make_interval(secs=>p_window_seconds) then now() else app_private.abuse_counters.window_started_at end,
  attempts=case when app_private.abuse_counters.window_started_at <= now()-make_interval(secs=>p_window_seconds) then 1 else app_private.abuse_counters.attempts+1 end
 returning * into v_counter;
 if v_counter.attempts>p_limit then
  insert into public.security_events(actor,event_type,context) values(v_actor,'RATE_LIMIT_EXCEEDED',jsonb_build_object('action',p_action,'window_seconds',p_window_seconds));
  return false;
 end if;
 return true;
end $$;
revoke all on function public.consume_action_budget(text,integer,integer) from public,anon;
grant execute on function public.consume_action_budget(text,integer,integer) to authenticated;

comment on table public.security_events is 'Immutable, low-detail security telemetry. Context is allow-listed by callers; sensitive values are prohibited.';
comment on function public.consume_action_budget(text,integer,integer) is 'Per-authenticated-actor fixed-window application boundary; external Auth/WAF limits remain required.';
