-- Toll/fine allocation, minimal communications history, and queued collection groundwork.
-- No provider integration or message delivery is performed by this migration.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED',
  'AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED',
  'PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED',
  'AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED',
  'EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED',
  'CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED',
  'COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED',
  'MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED',
  'NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED',
  'COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN'
));

alter table public.operational_exceptions drop constraint operational_exceptions_exception_type_check;
alter table public.operational_exceptions add constraint operational_exceptions_exception_type_check check (exception_type in (
  'OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','AGREEMENT_AWAITING_SIGNATURE','UNALLOCATED_FUNDS',
  'PAYMENT_ALLOCATION','SCHEDULE_EXTENSION_FAILURE','VEHICLE_SWAP_FAILURE','VEHICLE_STATE_INCONSISTENCY',
  'CUSTOMER_APPROVAL','PICKUP_PREREQUISITE','RETURN_PREREQUISITE','LICENCE_EXPIRY','REGISTRATION_EXPIRY',
  'RWC_EXPIRY','SERVICE_DUE','SERVICE_OVERDUE','VEHICLE_OFF_ROAD_TOO_LONG',
  'UNMATCHED_TOLL_FINE','AMBIGUOUS_TOLL_FINE','DISPUTED_NOTICE','BROKEN_PAYMENT_PROMISE',
  'OVERDUE_PAYMENT_ESCALATION','REMINDER_WORKFLOW_FAILURE'
));

create table public.toll_fine_notices (
  id uuid primary key default gen_random_uuid(),
  notice_type text not null check (notice_type in ('TOLL','FINE')),
  external_reference text,
  vehicle_id uuid not null references public.vehicles(id),
  registration_snapshot text not null check (btrim(registration_snapshot) <> ''),
  occurred_at timestamptz not null,
  issued_at timestamptz,
  amount numeric(12,2) not null check (amount >= 0),
  status text not null default 'NEW' check (status in ('NEW','MATCHED','REVIEW_REQUIRED','ASSIGNED_TO_DRIVER','NOMINATED','RESOLVED','DISPUTED')),
  source text not null check (btrim(source) <> '' and length(source) <= 100),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint notice_dates_valid check (issued_at is null or issued_at >= occurred_at)
);
create unique index toll_fine_source_reference on public.toll_fine_notices(source,external_reference) where external_reference is not null;
create index toll_fine_notices_queue on public.toll_fine_notices(status,occurred_at desc);
create trigger toll_fine_notices_touch before update on public.toll_fine_notices for each row execute function app_private.touch_updated_at();

create table public.notice_match_results (
  id uuid primary key default gen_random_uuid(), notice_id uuid not null references public.toll_fine_notices(id),
  attempted_at timestamptz not null default now(), candidate_count integer not null check(candidate_count >= 0),
  matched_assignment_id uuid references public.vehicle_assignments(id), matched_customer_id uuid references public.customers(id),
  match_status text not null check(match_status in ('EXACT','NO_MATCH','AMBIGUOUS')),
  confidence text not null check(confidence in ('HIGH','NONE','LOW')), reason text not null,
  evidence jsonb not null default '{}'::jsonb check(jsonb_typeof(evidence)='object'),
  constraint match_result_consistent check ((match_status='EXACT' and candidate_count=1 and matched_assignment_id is not null and matched_customer_id is not null) or (match_status<>'EXACT' and matched_assignment_id is null and matched_customer_id is null))
);
create index notice_match_history on public.notice_match_results(notice_id,attempted_at desc);

create table public.notice_allocations (
  id uuid primary key default gen_random_uuid(), notice_id uuid not null references public.toll_fine_notices(id),
  customer_id uuid references public.customers(id), assignment_id uuid references public.vehicle_assignments(id),
  decision text not null check(decision in ('CONFIRMED','REJECTED','MANUALLY_ASSIGNED')),
  reviewer uuid not null references public.staff_profiles(user_id), reason text not null check(btrim(reason)<>'' and length(reason)<=500),
  automated_match_result_id uuid references public.notice_match_results(id), reviewed_at timestamptz not null default now(),
  constraint allocation_driver_required check(decision='REJECTED' or customer_id is not null)
);
create index notice_allocation_history on public.notice_allocations(notice_id,reviewed_at desc);

create table public.notice_status_history (
  id uuid primary key default gen_random_uuid(), notice_id uuid not null references public.toll_fine_notices(id),
  from_status text, to_status text not null, actor uuid not null references public.staff_profiles(user_id),
  reason text not null check(btrim(reason)<>'' and length(reason)<=500), changed_at timestamptz not null default now()
);

create table public.communications (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id),
  agreement_id uuid references public.agreements(id), vehicle_id uuid references public.vehicles(id),
  channel text not null check(channel in ('PHONE','SMS','EMAIL','IN_PERSON','SYSTEM')),
  direction text not null check(direction in ('INBOUND','OUTBOUND','INTERNAL')),
  communication_type text not null check(communication_type in ('PAYMENT_REMINDER','PAYMENT_CALL','PAYMENT_PROMISE','TOLL_NOTICE','FINE_NOTICE','DOCUMENT_REQUEST','SERVICE_REMINDER','GENERAL')),
  status text not null check(btrim(status)<>'' and length(status)<=60), outcome text check(length(outcome)<=120),
  summary text not null check(btrim(summary)<>'' and length(summary)<=500), occurred_at timestamptz not null,
  created_by uuid not null references public.staff_profiles(user_id), created_at timestamptz not null default now()
);
create index communications_customer_history on public.communications(customer_id,occurred_at desc);

create table public.payment_promises (
  id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.agreements(id),
  customer_id uuid not null references public.customers(id), promised_amount numeric(12,2) not null check(promised_amount>0),
  promised_date date not null, note text check(length(note)<=500),
  status text not null default 'ACTIVE' check(status in ('ACTIVE','KEPT','BROKEN','CANCELLED')),
  created_by uuid not null references public.staff_profiles(user_id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index one_active_payment_promise on public.payment_promises(agreement_id) where status='ACTIVE';
create trigger payment_promises_touch before update on public.payment_promises for each row execute function app_private.touch_updated_at();

create table public.reminder_rules (
  stage text primary key check(stage in ('FIRST','SECOND','ESCALATION','STAFF_CALL')),
  overdue_days integer not null check(overdue_days>=0), sequence integer not null unique, enabled boolean not null default true,
  suppress_for_active_promise boolean not null default true, owner_exception boolean not null default false
);
insert into public.reminder_rules values ('FIRST',1,1,true,true,false),('SECOND',7,2,true,true,false),('ESCALATION',14,3,true,true,true),('STAFF_CALL',21,4,true,false,true);

create table public.reminder_actions (
  id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.agreements(id),
  customer_id uuid not null references public.customers(id), stage text not null references public.reminder_rules(stage),
  status text not null default 'QUEUED' check(status in ('QUEUED','COMPLETED','CANCELLED','FAILED')),
  overdue_amount numeric(12,2) not null check(overdue_amount>0), due_at timestamptz not null default now(),
  failure_count integer not null default 0 check(failure_count>=0), last_error text check(length(last_error)<=500),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index reminder_one_stage_per_agreement on public.reminder_actions(agreement_id,stage);
create index reminder_queue on public.reminder_actions(status,due_at);
create trigger reminder_actions_touch before update on public.reminder_actions for each row execute function app_private.touch_updated_at();

alter table public.toll_fine_notices enable row level security; alter table public.notice_match_results enable row level security;
alter table public.notice_allocations enable row level security; alter table public.notice_status_history enable row level security;
alter table public.communications enable row level security; alter table public.payment_promises enable row level security;
alter table public.reminder_rules enable row level security; alter table public.reminder_actions enable row level security;
create policy staff_read_notices on public.toll_fine_notices for select to authenticated using(app_private.is_staff());
create policy staff_read_matches on public.notice_match_results for select to authenticated using(app_private.is_staff());
create policy staff_read_allocations on public.notice_allocations for select to authenticated using(app_private.is_staff());
create policy staff_read_notice_history on public.notice_status_history for select to authenticated using(app_private.is_staff());
create policy staff_read_communications on public.communications for select to authenticated using(app_private.is_staff());
create policy staff_read_promises on public.payment_promises for select to authenticated using(app_private.is_staff());
create policy staff_read_reminder_rules on public.reminder_rules for select to authenticated using(app_private.is_staff());
create policy staff_read_reminders on public.reminder_actions for select to authenticated using(app_private.is_staff());
revoke all on public.toll_fine_notices,public.notice_match_results,public.notice_allocations,public.notice_status_history,public.communications,public.payment_promises,public.reminder_rules,public.reminder_actions from anon,authenticated;
grant select on public.toll_fine_notices,public.notice_match_results,public.notice_allocations,public.notice_status_history,public.communications,public.payment_promises,public.reminder_rules,public.reminder_actions to authenticated;

create or replace function app_private.match_notice(p_notice_id uuid,p_actor uuid) returns public.notice_match_results
language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices; r public.notice_match_results; c integer; a public.vehicle_assignments; ev jsonb;
begin
 select * into n from public.toll_fine_notices where id=p_notice_id for update; if not found then raise exception 'notice not found'; end if;
 select count(*),coalesce(jsonb_agg(jsonb_build_object('assignment_id',x.id,'customer_id',x.customer_id,'assigned_at',x.assigned_at,'returned_at',x.returned_at)),'[]'::jsonb)
 into c,ev from public.vehicle_assignments x where x.vehicle_id=n.vehicle_id and n.occurred_at>=x.assigned_at and (x.returned_at is null or n.occurred_at<x.returned_at);
 if c=1 then
   select * into a from public.vehicle_assignments x where x.vehicle_id=n.vehicle_id and n.occurred_at>=x.assigned_at and (x.returned_at is null or n.occurred_at<x.returned_at);
   insert into public.notice_match_results(notice_id,candidate_count,matched_assignment_id,matched_customer_id,match_status,confidence,reason,evidence)
   values(n.id,1,a.id,a.customer_id,'EXACT','HIGH','Exactly one vehicle assignment covered occurred_at',jsonb_build_object('vehicle_id',n.vehicle_id,'occurred_at',n.occurred_at,'candidates',ev)) returning * into r;
   update public.toll_fine_notices set status='MATCHED' where id=n.id;
 else
   insert into public.notice_match_results(notice_id,candidate_count,match_status,confidence,reason,evidence)
   values(n.id,c,case when c=0 then 'NO_MATCH' else 'AMBIGUOUS' end,case when c=0 then 'NONE' else 'LOW' end,
     case when c=0 then 'No vehicle assignment covered occurred_at' else 'Multiple vehicle assignments covered occurred_at; staff review required' end,
     jsonb_build_object('vehicle_id',n.vehicle_id,'occurred_at',n.occurred_at,'candidates',ev)) returning * into r;
   update public.toll_fine_notices set status='REVIEW_REQUIRED' where id=n.id;
   perform app_private.upsert_exception(case when c=0 then 'UNMATCHED_TOLL_FINE' else 'AMBIGUOUS_TOLL_FINE' end,'HIGH','toll_fine_notice',n.id,
     'notice-match:'||n.id::text,case when c=0 then 'Toll/fine has no assignment match' else 'Toll/fine has ambiguous assignment matches' end,
     jsonb_build_object('candidate_count',c,'match_result_id',r.id),false,p_actor);
 end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,'NOTICE_AUTO_MATCHED','toll_fine_notice',n.id,jsonb_build_object('match_result_id',r.id,'status',r.match_status,'candidate_count',c)); return r;
end $$;

create or replace function public.create_toll_fine_notice(p_notice_type text,p_external_reference text,p_vehicle_id uuid,p_registration_snapshot text,p_occurred_at timestamptz,p_issued_at timestamptz,p_amount numeric,p_source text)
returns public.toll_fine_notices language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 insert into public.toll_fine_notices(notice_type,external_reference,vehicle_id,registration_snapshot,occurred_at,issued_at,amount,source)
 values(p_notice_type,nullif(btrim(p_external_reference),''),p_vehicle_id,btrim(p_registration_snapshot),p_occurred_at,p_issued_at,p_amount,btrim(p_source)) returning * into n;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTICE_CREATED','toll_fine_notice',n.id,jsonb_build_object('notice_type',n.notice_type,'source',n.source));
 perform app_private.match_notice(n.id,auth.uid()); select * into n from public.toll_fine_notices where id=n.id; return n;
end $$;

create or replace function public.review_notice_allocation(p_notice_id uuid,p_decision text,p_customer_id uuid,p_assignment_id uuid,p_reason text)
returns public.notice_allocations language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices; m public.notice_match_results; a public.notice_allocations; old text;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if btrim(coalesce(p_reason,''))='' then raise exception 'override reason required' using errcode='22023'; end if;
 select * into n from public.toll_fine_notices where id=p_notice_id for update; if not found then raise exception 'notice not found'; end if; old:=n.status;
 select * into m from public.notice_match_results where notice_id=n.id order by attempted_at desc limit 1;
 if p_decision='CONFIRMED' then
   if m.match_status<>'EXACT' or p_customer_id is distinct from m.matched_customer_id or p_assignment_id is distinct from m.matched_assignment_id then raise exception 'confirmation must use exact automated match'; end if;
 elsif p_decision='MANUALLY_ASSIGNED' then
   if p_customer_id is null then raise exception 'manual assignment requires customer'; end if;
   if p_assignment_id is not null and not exists(select 1 from public.vehicle_assignments where id=p_assignment_id and customer_id=p_customer_id) then raise exception 'assignment does not belong to customer'; end if;
 elsif p_decision<>'REJECTED' then raise exception 'invalid allocation decision'; end if;
 insert into public.notice_allocations(notice_id,customer_id,assignment_id,decision,reviewer,reason,automated_match_result_id)
 values(n.id,p_customer_id,p_assignment_id,p_decision,auth.uid(),btrim(p_reason),m.id) returning * into a;
 update public.toll_fine_notices set status=case when p_decision='REJECTED' then 'REVIEW_REQUIRED' else 'ASSIGNED_TO_DRIVER' end where id=n.id;
 insert into public.notice_status_history(notice_id,from_status,to_status,actor,reason) values(n.id,old,case when p_decision='REJECTED' then 'REVIEW_REQUIRED' else 'ASSIGNED_TO_DRIVER' end,auth.uid(),btrim(p_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTICE_ALLOCATION_CHANGED','toll_fine_notice',n.id,jsonb_build_object('decision',p_decision,'customer_id',p_customer_id,'assignment_id',p_assignment_id,'automated_match_result_id',m.id,'reason',btrim(p_reason))); return a;
end $$;

create or replace function public.transition_toll_fine_notice(p_notice_id uuid,p_status text,p_reason text) returns public.toll_fine_notices
language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices; old text;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if btrim(coalesce(p_reason,''))='' then raise exception 'transition reason required'; end if;
 select * into n from public.toll_fine_notices where id=p_notice_id for update; if not found then raise exception 'notice not found'; end if; old:=n.status;
 if not ((old='ASSIGNED_TO_DRIVER' and p_status in('NOMINATED','RESOLVED','DISPUTED')) or (old='NOMINATED' and p_status in('RESOLVED','DISPUTED')) or (old='DISPUTED' and p_status in('RESOLVED','ASSIGNED_TO_DRIVER'))) then raise exception 'invalid notice status transition'; end if;
 update public.toll_fine_notices set status=p_status where id=n.id returning * into n;
 insert into public.notice_status_history(notice_id,from_status,to_status,actor,reason) values(n.id,old,p_status,auth.uid(),btrim(p_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTICE_STATUS_CHANGED','toll_fine_notice',n.id,jsonb_build_object('from',old,'to',p_status,'reason',btrim(p_reason)));
 if p_status='DISPUTED' then perform app_private.upsert_exception('DISPUTED_NOTICE','HIGH','toll_fine_notice',n.id,'disputed-notice:'||n.id::text,'Toll/fine notice is disputed','{}',true,auth.uid()); end if; return n;
end $$;

create or replace function public.log_communication(p_customer_id uuid,p_agreement_id uuid,p_vehicle_id uuid,p_channel text,p_direction text,p_type text,p_status text,p_outcome text,p_summary text,p_occurred_at timestamptz)
returns public.communications language plpgsql security definer set search_path='' as $$ declare c public.communications;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_agreement_id is not null and not exists(select 1 from public.agreements where id=p_agreement_id and customer_id=p_customer_id) then raise exception 'agreement/customer mismatch'; end if;
 insert into public.communications(customer_id,agreement_id,vehicle_id,channel,direction,communication_type,status,outcome,summary,occurred_at,created_by)
 values(p_customer_id,p_agreement_id,p_vehicle_id,p_channel,p_direction,p_type,btrim(p_status),nullif(btrim(p_outcome),''),btrim(p_summary),p_occurred_at,auth.uid()) returning * into c;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'COMMUNICATION_LOGGED','communication',c.id,jsonb_build_object('customer_id',p_customer_id,'type',p_type,'channel',p_channel)); return c; end $$;

create or replace function public.create_payment_promise(p_agreement_id uuid,p_amount numeric,p_date date,p_note text) returns public.payment_promises
language plpgsql security definer set search_path='' as $$ declare p public.payment_promises; a public.agreements;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 select * into a from public.agreements where id=p_agreement_id; if not found then raise exception 'agreement not found'; end if;
 if p_date<current_date then raise exception 'promise date cannot be in the past'; end if;
 insert into public.payment_promises(agreement_id,customer_id,promised_amount,promised_date,note,created_by) values(a.id,a.customer_id,p_amount,p_date,nullif(btrim(p_note),''),auth.uid()) returning * into p;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PROMISE_CREATED','payment_promise',p.id,jsonb_build_object('agreement_id',a.id,'amount',p_amount,'date',p_date)); return p; end $$;

create or replace function public.change_payment_promise(p_promise_id uuid,p_status text,p_note text default null) returns public.payment_promises
language plpgsql security definer set search_path='' as $$ declare p public.payment_promises; old text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into p from public.payment_promises where id=p_promise_id for update; if not found then raise exception 'promise not found'; end if; old:=p.status;
 if old<>'ACTIVE' or p_status not in('KEPT','BROKEN','CANCELLED') then raise exception 'invalid promise transition'; end if;
 update public.payment_promises set status=p_status,note=coalesce(nullif(btrim(p_note),''),note) where id=p.id returning * into p;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PROMISE_CHANGED','payment_promise',p.id,jsonb_build_object('from',old,'to',p_status)); return p; end $$;

create or replace function public.run_collection_workflows(p_as_of date default current_date) returns table(reminders_queued integer,promises_broken integer,exceptions_refreshed integer)
language plpgsql security definer set search_path='' as $$ declare x record; q int:=0; b int:=0; e int:=0; rid uuid;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 for x in select p.*,s.overdue_amount from public.payment_promises p join public.agreement_payment_summary s on s.agreement_id=p.agreement_id where p.status='ACTIVE' and p.promised_date<p_as_of and s.overdue_amount>0 for update of p loop
   update public.payment_promises set status='BROKEN' where id=x.id; b:=b+1;
   perform app_private.upsert_exception('BROKEN_PAYMENT_PROMISE','HIGH','agreement',x.agreement_id,'broken-promise:'||x.agreement_id::text,'Payment promise passed without clearing arrears',jsonb_build_object('promise_id',x.id,'promised_date',x.promised_date),true,auth.uid()); e:=e+1;
   insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PROMISE_BROKEN','payment_promise',x.id,jsonb_build_object('agreement_id',x.agreement_id));
 end loop;
 update public.reminder_actions r set status='CANCELLED' where r.status='QUEUED' and not exists(select 1 from public.agreement_payment_summary s where s.agreement_id=r.agreement_id and s.overdue_amount>0);
 for x in select a.id agreement_id,a.customer_id,s.overdue_amount,s.oldest_overdue_date,rr.stage,rr.owner_exception
   from public.agreements a join public.agreement_payment_summary s on s.agreement_id=a.id join public.reminder_rules rr on rr.enabled and rr.overdue_days<=p_as_of-s.oldest_overdue_date
   where a.status='ACTIVE' and s.overdue_amount>0 and (not rr.suppress_for_active_promise or not exists(select 1 from public.payment_promises p where p.agreement_id=a.id and p.status='ACTIVE' and p.promised_date>=p_as_of)) loop
   insert into public.reminder_actions(agreement_id,customer_id,stage,overdue_amount) values(x.agreement_id,x.customer_id,x.stage,x.overdue_amount) on conflict(agreement_id,stage) do nothing returning id into rid;
   if rid is not null then q:=q+1; insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'REMINDER_QUEUED','reminder_action',rid,jsonb_build_object('agreement_id',x.agreement_id,'stage',x.stage,'overdue_amount',x.overdue_amount)); end if; rid:=null;
   if x.owner_exception then perform app_private.upsert_exception('OVERDUE_PAYMENT_ESCALATION','HIGH','agreement',x.agreement_id,'collection-escalation:'||x.agreement_id::text,'Overdue agreement reached collection escalation threshold',jsonb_build_object('overdue_amount',x.overdue_amount,'stage',x.stage),true,auth.uid()); e:=e+1; end if;
 end loop;
 for x in select * from public.reminder_actions where status='FAILED' and failure_count>=3 loop perform app_private.upsert_exception('REMINDER_WORKFLOW_FAILURE','HIGH','agreement',x.agreement_id,'reminder-failure:'||x.agreement_id::text,'Reminder workflow has repeatedly failed',jsonb_build_object('reminder_action_id',x.id,'failure_count',x.failure_count),true,auth.uid()); e:=e+1; end loop;
 return query select q,b,e; end $$;

revoke all on function public.create_toll_fine_notice(text,text,uuid,text,timestamptz,timestamptz,numeric,text),public.review_notice_allocation(uuid,text,uuid,uuid,text),public.transition_toll_fine_notice(uuid,text,text),public.log_communication(uuid,uuid,uuid,text,text,text,text,text,text,timestamptz),public.create_payment_promise(uuid,numeric,date,text),public.change_payment_promise(uuid,text,text),public.run_collection_workflows(date) from public;
grant execute on function public.create_toll_fine_notice(text,text,uuid,text,timestamptz,timestamptz,numeric,text),public.review_notice_allocation(uuid,text,uuid,uuid,text),public.transition_toll_fine_notice(uuid,text,text),public.log_communication(uuid,uuid,uuid,text,text,text,text,text,text,timestamptz),public.create_payment_promise(uuid,numeric,date,text),public.change_payment_promise(uuid,text,text),public.run_collection_workflows(date) to authenticated;
