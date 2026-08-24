-- Fleet schedules and durable vehicle issue management.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED'
));

alter table public.operational_exceptions drop constraint operational_exceptions_exception_type_check;
alter table public.operational_exceptions add constraint operational_exceptions_exception_type_check check (exception_type in (
  'OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','AGREEMENT_AWAITING_SIGNATURE','UNALLOCATED_FUNDS','PAYMENT_ALLOCATION','SCHEDULE_EXTENSION_FAILURE','VEHICLE_SWAP_FAILURE','VEHICLE_STATE_INCONSISTENCY','CUSTOMER_APPROVAL','PICKUP_PREREQUISITE','RETURN_PREREQUISITE','LICENCE_EXPIRY','REGISTRATION_EXPIRY','RWC_EXPIRY','SERVICE_DUE','SERVICE_OVERDUE','VEHICLE_OFF_ROAD_TOO_LONG','UNMATCHED_TOLL_FINE','AMBIGUOUS_TOLL_FINE','DISPUTED_NOTICE','BROKEN_PAYMENT_PROMISE','OVERDUE_PAYMENT_ESCALATION','REMINDER_WORKFLOW_FAILURE','MESSAGE_MISSING_CONTACT','MESSAGE_INVALID_CONTACT','MESSAGE_REPEATED_FAILURE','MESSAGE_STUCK_QUEUE','UNMATCHED_BANK_RECEIPT','AMBIGUOUS_BANK_MATCH','SUSPICIOUS_BANK_DUPLICATE','UNUSUALLY_LARGE_RECEIPT','UNRESOLVED_UNALLOCATED_AMOUNT','BANK_REVERSAL_REVIEW','BANK_IMPORT_BATCH_FAILURE','VEHICLE_ISSUE'
));

create table public.vehicle_issues (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id),
  customer_id uuid references public.customers(id),
  agreement_id uuid references public.agreements(id),
  assigned_to uuid references public.staff_profiles(user_id),
  created_by uuid not null references public.staff_profiles(user_id),
  severity text not null check(severity in ('LOW','MEDIUM','HIGH','CRITICAL')),
  category text not null check(category in ('BREAKDOWN','WARNING_LIGHT','ACCIDENT','DAMAGE','PARKING','TYRE','BATTERY','SERVICE','CLEANING','CUSTOMER_COMPLAINT','OTHER')),
  description text not null check(btrim(description)<>'' and length(description)<=2000),
  status text not null default 'OPEN' check(status in ('OPEN','ASSIGNED','IN_PROGRESS','WAITING_CUSTOMER','WAITING_PARTS','RESOLVED','CANCELLED')),
  resolution text check(resolution is null or (btrim(resolution)<>'' and length(resolution)<=2000)),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_issue_resolution_consistent check((status='RESOLVED' and resolved_at is not null and resolution is not null) or (status<>'RESOLVED' and resolved_at is null and resolution is null))
);
create index vehicle_issues_active_vehicle on public.vehicle_issues(vehicle_id,status,severity);
create index vehicle_issues_assignee on public.vehicle_issues(assigned_to,status) where status not in ('RESOLVED','CANCELLED');
create trigger vehicle_issues_touch_updated_at before update on public.vehicle_issues for each row execute function app_private.touch_updated_at();

create table public.vehicle_issue_events (
  id bigint generated always as identity primary key,
  vehicle_issue_id uuid not null references public.vehicle_issues(id),
  actor uuid not null references public.staff_profiles(user_id),
  event_type text not null check(event_type in ('CREATED','ASSIGNED','STATUS_CHANGED','NOTE_ADDED','RESOLVED','CANCELLED')),
  from_status text,
  to_status text,
  note text check(note is null or (btrim(note)<>'' and length(note)<=2000)),
  metadata jsonb not null default '{}'::jsonb check(jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default now()
);
create index vehicle_issue_events_history on public.vehicle_issue_events(vehicle_issue_id,created_at,id);
create or replace function app_private.reject_vehicle_issue_event_mutation() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'vehicle issue history is immutable' using errcode='42501'; end $$;
create trigger vehicle_issue_events_immutable before update or delete on public.vehicle_issue_events for each row execute function app_private.reject_vehicle_issue_event_mutation();

alter table public.pickup_checklists add column scheduled_at timestamptz, add column actual_at timestamptz, add column staff_notes text check(staff_notes is null or length(staff_notes)<=2000);
alter table public.return_checklists add column scheduled_at timestamptz, add column actual_at timestamptz, add column staff_notes text check(staff_notes is null or length(staff_notes)<=2000);
update public.pickup_checklists p set scheduled_at=a.start_date::timestamptz from public.agreements a where a.id=p.agreement_id and p.scheduled_at is null;
update public.return_checklists r set scheduled_at=a.end_date::timestamptz from public.vehicle_assignments va join public.agreements a on a.vehicle_id=va.vehicle_id and a.customer_id=va.customer_id where va.id=r.assignment_id and r.scheduled_at is null and a.end_date is not null;
update public.pickup_checklists set actual_at=completed_at where status='COMPLETED';
update public.return_checklists set actual_at=completed_at where status='COMPLETED';

alter table public.vehicle_issues enable row level security;
alter table public.vehicle_issue_events enable row level security;
create policy staff_read_vehicle_issues on public.vehicle_issues for select to authenticated using(app_private.is_staff());
create policy staff_read_vehicle_issue_events on public.vehicle_issue_events for select to authenticated using(app_private.is_staff());
revoke all on public.vehicle_issues,public.vehicle_issue_events from anon,authenticated;
grant select on public.vehicle_issues,public.vehicle_issue_events to authenticated;

create or replace function app_private.vehicle_has_blocking_issue(p_vehicle_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.vehicle_issues i where i.vehicle_id=p_vehicle_id and i.status not in ('RESOLVED','CANCELLED') and (i.severity in ('HIGH','CRITICAL') or i.category in ('BREAKDOWN','ACCIDENT','TYRE','BATTERY','SERVICE')))
$$;
revoke all on function app_private.vehicle_has_blocking_issue(uuid) from public;
grant execute on function app_private.vehicle_has_blocking_issue(uuid) to authenticated;

create or replace view public.fleet_operations with (security_invoker=true) as
select v.id,v.registration,v.make,v.model,v.year,v.odometer,v.operational_status,
  c.id current_customer_id,c.full_name current_customer,a.id agreement_id,a.status agreement_status,
  p.scheduled_at next_pickup_at,r.scheduled_at next_return_at,
  (select count(*) from public.vehicle_issues i where i.vehicle_id=v.id and i.status not in ('RESOLVED','CANCELLED')) open_issue_count,
  ms.status maintenance_status,
  (v.operational_status='AVAILABLE' and not app_private.vehicle_has_blocking_issue(v.id) and app_private.vehicle_is_compliant(v.id) and not exists(select 1 from public.maintenance_jobs mj where mj.vehicle_id=v.id and mj.status in ('OPEN','IN_PROGRESS'))) ready_for_allocation
from public.vehicles v
left join public.vehicle_assignments va on va.vehicle_id=v.id and va.assignment_status='ACTIVE'
left join public.customers c on c.id=va.customer_id
left join public.agreements a on a.vehicle_id=v.id and a.customer_id=va.customer_id and a.status in ('ACTIVE','SUSPENDED')
left join public.pickup_checklists p on p.vehicle_id=v.id and p.status not in ('COMPLETED','CANCELLED')
left join public.return_checklists r on r.assignment_id=va.id and r.status not in ('COMPLETED','CANCELLED')
left join public.vehicle_maintenance_status ms on ms.vehicle_id=v.id;
grant select on public.fleet_operations to authenticated;

create or replace function app_private.sync_vehicle_issue_state(p_vehicle_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare target text;
begin
  if app_private.vehicle_has_blocking_issue(p_vehicle_id) then
    update public.vehicles set operational_status='OFF_ROAD' where id=p_vehicle_id and operational_status not in ('WORKSHOP','OFF_ROAD');
  elsif not exists(select 1 from public.maintenance_jobs j where j.vehicle_id=p_vehicle_id and j.status in ('OPEN','IN_PROGRESS')) then
    target:=case when exists(select 1 from public.vehicle_assignments va where va.vehicle_id=p_vehicle_id and va.assignment_status='ACTIVE') then 'ASSIGNED' else 'AVAILABLE' end;
    update public.vehicles set operational_status=target where id=p_vehicle_id and operational_status='OFF_ROAD';
  end if;
end $$;

create or replace function public.create_vehicle_issue(p_vehicle_id uuid,p_customer_id uuid,p_agreement_id uuid,p_severity text,p_category text,p_description text,p_assigned_to uuid default null) returns public.vehicle_issues language plpgsql security definer set search_path='' as $$
declare i public.vehicle_issues;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if p_assigned_to is not null and not exists(select 1 from public.staff_profiles s where s.user_id=p_assigned_to and s.status='ACTIVE' and s.is_active) then raise exception 'active assignee not found'; end if;
  if p_agreement_id is not null and not exists(select 1 from public.agreements a where a.id=p_agreement_id and a.vehicle_id=p_vehicle_id and (p_customer_id is null or a.customer_id=p_customer_id)) then raise exception 'issue agreement context does not match vehicle and customer'; end if;
  insert into public.vehicle_issues(vehicle_id,customer_id,agreement_id,assigned_to,created_by,severity,category,description,status)
  values(p_vehicle_id,p_customer_id,p_agreement_id,p_assigned_to,auth.uid(),p_severity,p_category,btrim(p_description),case when p_assigned_to is null then 'OPEN' else 'ASSIGNED' end) returning * into i;
  insert into public.vehicle_issue_events(vehicle_issue_id,actor,event_type,to_status,metadata) values(i.id,auth.uid(),'CREATED',i.status,jsonb_build_object('severity',i.severity,'category',i.category));
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'VEHICLE_ISSUE_CREATED','vehicle_issue',i.id,jsonb_build_object('vehicle_id',i.vehicle_id,'severity',i.severity,'category',i.category));
  if i.severity in ('HIGH','CRITICAL') or i.category in ('BREAKDOWN','ACCIDENT','PARKING') then perform app_private.upsert_exception('VEHICLE_ISSUE',case when i.category in ('BREAKDOWN','ACCIDENT') and i.severity='HIGH' then 'CRITICAL' else i.severity end,'vehicle_issue',i.id,'vehicle-issue:'||i.id,initcap(replace(i.category,'_',' '))||': '||left(i.description,300),jsonb_build_object('vehicle_id',i.vehicle_id),i.severity in ('HIGH','CRITICAL'),auth.uid()); end if;
  perform app_private.sync_vehicle_issue_state(i.vehicle_id); return i;
end $$;

create or replace function public.assign_vehicle_issue(p_issue_id uuid,p_assigned_to uuid) returns public.vehicle_issues language plpgsql security definer set search_path='' as $$
declare i public.vehicle_issues; old_status text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if not exists(select 1 from public.staff_profiles where user_id=p_assigned_to and status='ACTIVE' and is_active) then raise exception 'active assignee not found'; end if;
 select status into old_status from public.vehicle_issues where id=p_issue_id and status not in ('RESOLVED','CANCELLED') for update; if not found then raise exception 'open vehicle issue not found'; end if;
 update public.vehicle_issues set assigned_to=p_assigned_to,status=case when status='OPEN' then 'ASSIGNED' else status end where id=p_issue_id returning * into i;
 insert into public.vehicle_issue_events(vehicle_issue_id,actor,event_type,from_status,to_status,metadata) values(i.id,auth.uid(),'ASSIGNED',old_status,i.status,jsonb_build_object('assigned_to',p_assigned_to));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'VEHICLE_ISSUE_ASSIGNED','vehicle_issue',i.id,jsonb_build_object('assigned_to',p_assigned_to)); return i; end $$;

create or replace function public.update_vehicle_issue_status(p_issue_id uuid,p_status text,p_note text default null) returns public.vehicle_issues language plpgsql security definer set search_path='' as $$
declare i public.vehicle_issues; old_status text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_status not in ('OPEN','ASSIGNED','IN_PROGRESS','WAITING_CUSTOMER','WAITING_PARTS','CANCELLED') then raise exception 'invalid issue status transition' using errcode='22023'; end if;
 select status into old_status from public.vehicle_issues where id=p_issue_id and status not in ('RESOLVED','CANCELLED') for update; if not found then raise exception 'open vehicle issue not found'; end if;
 if p_status='ASSIGNED' and not exists(select 1 from public.vehicle_issues where id=p_issue_id and assigned_to is not null) then raise exception 'issue must have an assignee'; end if;
 update public.vehicle_issues set status=p_status where id=p_issue_id returning * into i;
 insert into public.vehicle_issue_events(vehicle_issue_id,actor,event_type,from_status,to_status,note) values(i.id,auth.uid(),case when p_status='CANCELLED' then 'CANCELLED' else 'STATUS_CHANGED' end,old_status,p_status,nullif(btrim(p_note),''));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'VEHICLE_ISSUE_STATUS_CHANGED','vehicle_issue',i.id,jsonb_build_object('from',old_status,'to',p_status));
 if p_status='CANCELLED' then update public.operational_exceptions set status='RESOLVED',resolved_at=now(),resolution_note='Vehicle issue cancelled' where dedup_key='vehicle-issue:'||i.id and status<>'RESOLVED'; end if;
 perform app_private.sync_vehicle_issue_state(i.vehicle_id); return i; end $$;

create or replace function public.add_vehicle_issue_note(p_issue_id uuid,p_note text) returns public.vehicle_issue_events language plpgsql security definer set search_path='' as $$
declare e public.vehicle_issue_events;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if btrim(coalesce(p_note,''))='' then raise exception 'note is required' using errcode='22023'; end if;
 if not exists(select 1 from public.vehicle_issues where id=p_issue_id) then raise exception 'vehicle issue not found'; end if;
 insert into public.vehicle_issue_events(vehicle_issue_id,actor,event_type,note) values(p_issue_id,auth.uid(),'NOTE_ADDED',btrim(p_note)) returning * into e;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'VEHICLE_ISSUE_NOTE_ADDED','vehicle_issue',p_issue_id,'{}'); return e; end $$;

create or replace function public.resolve_vehicle_issue(p_issue_id uuid,p_resolution text) returns public.vehicle_issues language plpgsql security definer set search_path='' as $$
declare i public.vehicle_issues; old_status text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if btrim(coalesce(p_resolution,''))='' then raise exception 'resolution is required' using errcode='22023'; end if;
 select status into old_status from public.vehicle_issues where id=p_issue_id and status not in ('RESOLVED','CANCELLED') for update; if not found then raise exception 'open vehicle issue not found'; end if;
 update public.vehicle_issues set status='RESOLVED',resolution=btrim(p_resolution),resolved_at=now() where id=p_issue_id returning * into i;
 insert into public.vehicle_issue_events(vehicle_issue_id,actor,event_type,from_status,to_status,note) values(i.id,auth.uid(),'RESOLVED',old_status,'RESOLVED',btrim(p_resolution));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'VEHICLE_ISSUE_RESOLVED','vehicle_issue',i.id,jsonb_build_object('vehicle_id',i.vehicle_id));
 update public.operational_exceptions set status='RESOLVED',resolved_at=now(),resolution_note='Vehicle issue resolved' where dedup_key='vehicle-issue:'||i.id and status<>'RESOLVED';
 perform app_private.sync_vehicle_issue_state(i.vehicle_id); return i; end $$;

create or replace function public.schedule_pickup(p_agreement_id uuid,p_scheduled_at timestamptz,p_staff_notes text default null) returns public.pickup_checklists language plpgsql security definer set search_path='' as $$
declare a public.agreements; p public.pickup_checklists;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_scheduled_at is null then raise exception 'pickup schedule is required' using errcode='22023'; end if;
 select * into a from public.agreements where id=p_agreement_id and status in ('PENDING_SIGNATURE','ACTIVE'); if not found then raise exception 'schedulable agreement not found'; end if;
 insert into public.pickup_checklists(agreement_id,customer_id,vehicle_id,scheduled_at,staff_notes) values(a.id,a.customer_id,a.vehicle_id,p_scheduled_at,nullif(btrim(p_staff_notes),'')) on conflict(agreement_id) do update set scheduled_at=excluded.scheduled_at,staff_notes=excluded.staff_notes,updated_at=now() where public.pickup_checklists.status not in ('COMPLETED','CANCELLED') returning * into p;
 if p.id is null then raise exception 'completed or cancelled pickup cannot be rescheduled'; end if;
 update public.vehicles set operational_status='PICKUP_PENDING' where id=a.vehicle_id and operational_status='AVAILABLE' and not app_private.vehicle_has_blocking_issue(a.vehicle_id);
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PICKUP_SCHEDULED','pickup_checklist',p.id,jsonb_build_object('scheduled_at',p_scheduled_at,'vehicle_id',a.vehicle_id)); return p; end $$;

create or replace function public.schedule_return(p_assignment_id uuid,p_scheduled_at timestamptz,p_staff_notes text default null) returns public.return_checklists language plpgsql security definer set search_path='' as $$
declare a public.vehicle_assignments; r public.return_checklists;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_scheduled_at is null then raise exception 'return schedule is required' using errcode='22023'; end if;
 select * into a from public.vehicle_assignments where id=p_assignment_id and assignment_status='ACTIVE'; if not found then raise exception 'active assignment not found'; end if;
 insert into public.return_checklists(assignment_id,scheduled_at,staff_notes) values(a.id,p_scheduled_at,nullif(btrim(p_staff_notes),'')) on conflict(assignment_id) do update set scheduled_at=excluded.scheduled_at,staff_notes=excluded.staff_notes,updated_at=now() where public.return_checklists.status not in ('COMPLETED','CANCELLED') returning * into r;
 if r.id is null then raise exception 'completed or cancelled return cannot be rescheduled'; end if;
 update public.vehicles set operational_status='RETURN_PENDING' where id=a.vehicle_id and operational_status='ASSIGNED';
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'RETURN_SCHEDULED','return_checklist',r.id,jsonb_build_object('scheduled_at',p_scheduled_at,'vehicle_id',a.vehicle_id)); return r; end $$;

-- Existing completion remains compatible and now records explicit actual times and issue-safe release state.
create or replace function public.complete_pickup(p_checklist_id uuid,p_odometer integer) returns public.vehicle_assignments language plpgsql security definer set search_path='' as $$
declare c public.pickup_checklists; a public.agreements; v public.vehicle_assignments; ve public.vehicles;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into c from public.pickup_checklists where id=p_checklist_id and status not in ('COMPLETED','CANCELLED') for update; if not found then raise exception 'open pickup checklist not found'; end if;
 select * into a from public.agreements where id=c.agreement_id for update; select * into ve from public.vehicles where id=c.vehicle_id for update;
 if app_private.vehicle_has_blocking_issue(c.vehicle_id) then raise exception 'vehicle has an unresolved blocking issue'; end if;
 if not app_private.customer_is_ready(c.customer_id) then raise exception 'customer prerequisites are incomplete'; end if; if not app_private.vehicle_is_compliant(c.vehicle_id) then raise exception 'vehicle compliance is incomplete or expired'; end if; if ve.operational_status not in ('AVAILABLE','PICKUP_PENDING') then raise exception 'vehicle is not available'; end if;
 perform app_private.record_odometer(c.vehicle_id,p_odometer,'PICKUP',now()); insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values(c.customer_id,c.vehicle_id,now(),p_odometer,'ACTIVE',auth.uid()) returning * into v;
 if a.status='PENDING_SIGNATURE' then raise exception 'agreement must be active before pickup'; end if; update public.vehicles set operational_status='ASSIGNED' where id=c.vehicle_id; update public.pickup_checklists set status='COMPLETED',pickup_odometer=p_odometer,completed_by=auth.uid(),completed_at=now(),actual_at=now() where id=c.id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PICKUP_COMPLETED','pickup_checklist',c.id,jsonb_build_object('assignment_id',v.id,'agreement_id',a.id)); return v; end $$;

create or replace function public.complete_return(p_checklist_id uuid,p_odometer integer,p_condition text,p_open_issue boolean,p_disposition text) returns public.vehicle_assignments language plpgsql security definer set search_path='' as $$
declare c public.return_checklists; a public.vehicle_assignments; target text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_condition not in ('GOOD','DAMAGE_NOTED','UNSAFE') or p_disposition not in ('RELEASE','WORKSHOP','OFF_ROAD') then raise exception 'invalid return state' using errcode='22023'; end if;
 select * into c from public.return_checklists where id=p_checklist_id and status not in ('COMPLETED','CANCELLED') for update; if not found then raise exception 'open return checklist not found'; end if; select * into a from public.vehicle_assignments where id=c.assignment_id and assignment_status='ACTIVE' for update; if not found then raise exception 'active assignment not found'; end if;
 perform app_private.record_odometer(a.vehicle_id,p_odometer,'RETURN',now()); update public.vehicle_assignments set assignment_status='RETURNED',returned_at=greatest(now(),a.assigned_at+interval '1 microsecond'),return_odometer=p_odometer where id=a.id returning * into a;
 target:=case when p_disposition='RELEASE' and not app_private.vehicle_has_blocking_issue(a.vehicle_id) then 'AVAILABLE' when p_disposition='WORKSHOP' then 'WORKSHOP' else 'OFF_ROAD' end; update public.vehicles set operational_status=target where id=a.vehicle_id;
 update public.return_checklists set status='COMPLETED',return_odometer=p_odometer,return_condition=p_condition,open_issue=coalesce(p_open_issue,false),disposition=p_disposition,completed_by=auth.uid(),completed_at=now(),actual_at=now() where id=c.id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'RETURN_COMPLETED','return_checklist',c.id,jsonb_build_object('assignment_id',a.id,'condition',p_condition,'open_issue',p_open_issue,'disposition',p_disposition)); return a; end $$;

revoke all on function public.create_vehicle_issue(uuid,uuid,uuid,text,text,text,uuid),public.assign_vehicle_issue(uuid,uuid),public.update_vehicle_issue_status(uuid,text,text),public.add_vehicle_issue_note(uuid,text),public.resolve_vehicle_issue(uuid,text),public.schedule_pickup(uuid,timestamptz,text),public.schedule_return(uuid,timestamptz,text) from public;
grant execute on function public.create_vehicle_issue(uuid,uuid,uuid,text,text,text,uuid),public.assign_vehicle_issue(uuid,uuid),public.update_vehicle_issue_status(uuid,text,text),public.add_vehicle_issue_note(uuid,text),public.resolve_vehicle_issue(uuid,text),public.schedule_pickup(uuid,timestamptz,text),public.schedule_return(uuid,timestamptz,text) to authenticated;
