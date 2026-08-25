-- Provider-neutral toll and infringement automation foundation. Synthetic inputs only;
-- this migration performs no external network calls and stores no provider credentials.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED','MAINTENANCE_RECORD_CREATED','MAINTENANCE_RECORD_STATUS_CHANGED','MAINTENANCE_RECORD_COMPLETED','SERVICE_INTERVAL_CHANGED','COMPLIANCE_ATTENTION_REFRESHED','NOTIFICATION_CREATED','NOTIFICATION_CANCELLED','NOTIFICATION_RETRIED','NOTIFICATION_CLAIMED','NOTIFICATION_STATUS_CHANGED','NOTIFICATION_MANUALLY_QUEUED','CUSTOMER_PORTAL_ISSUE_SUBMITTED','CUSTOMER_PORTAL_RESCHEDULE_REQUESTED','CUSTOMER_PORTAL_PROFILE_CHANGE_REQUESTED','CUSTOMER_PORTAL_ACCESS_CHANGED','PORTAL_REQUEST_SUBMITTED','PORTAL_REQUEST_ASSIGNED','PORTAL_REQUEST_APPROVED','PORTAL_REQUEST_DECLINED','PORTAL_REQUEST_COMPLETED','DOCUMENT_UPLOADED','DOCUMENT_REPLACED','DOCUMENT_ACCESS_ISSUED','AGREEMENT_DOCUMENT_UPLOADED',
  'TOLL_FINE_IMPORT','TOLL_FINE_MATCH','TOLL_FINE_CONFIRM','TOLL_FINE_OVERRIDE','TOLL_FINE_DISPUTE','TOLL_FINE_TRANSFER_PENDING','TOLL_FINE_TRANSFERRED','TOLL_FINE_CANCELLED'
));

alter table public.toll_fine_notices rename column notice_type to type;
alter table public.toll_fine_notices rename column registration_snapshot to registration;
alter table public.toll_fine_notices rename column occurred_at to event_at;
alter table public.toll_fine_notices drop constraint toll_fine_notices_notice_type_check;
alter table public.toll_fine_notices drop constraint toll_fine_notices_status_check;
alter table public.toll_fine_notices alter column vehicle_id drop not null;
alter table public.toll_fine_notices alter column event_at drop not null;
update public.toll_fine_notices set type='OTHER_INFRINGEMENT' where type='FINE';
update public.toll_fine_notices set status=case status when 'NEW' then 'IMPORTED' when 'REVIEW_REQUIRED' then 'NEEDS_REVIEW' when 'ASSIGNED_TO_DRIVER' then 'CONFIRMED' when 'NOMINATED' then 'TRANSFER_PENDING' when 'RESOLVED' then 'TRANSFERRED' else status end;
alter table public.toll_fine_notices
  alter column status set default 'IMPORTED',
  add constraint toll_fine_notices_type_check check(type in ('TOLL','PARKING_FINE','SPEEDING_FINE','OTHER_INFRINGEMENT')),
  add constraint toll_fine_notices_status_check check(status in ('IMPORTED','MATCHED','NEEDS_REVIEW','CONFIRMED','TRANSFER_PENDING','TRANSFERRED','DISPUTED','CANCELLED')),
  add column authority_provider text check(authority_provider is null or length(authority_provider)<=160),
  add column matched_customer_id uuid references public.customers(id),
  add column matched_agreement_id uuid references public.agreements(id),
  add column matched_assignment_id uuid references public.vehicle_assignments(id),
  add column match_confidence text not null default 'NO_MATCH' check(match_confidence in ('HIGH','MEDIUM','LOW','NO_MATCH','AMBIGUOUS')),
  add column reviewed_by uuid references public.staff_profiles(user_id),
  add column reviewed_at timestamptz,
  add column transferred_at timestamptz,
  add column notes text check(notes is null or length(notes)<=2000),
  add column original_import_data jsonb not null default '{}'::jsonb check(jsonb_typeof(original_import_data)='object'),
  add column import_batch_id uuid,
  add constraint toll_fine_review_pair check((reviewed_by is null)=(reviewed_at is null)),
  add constraint toll_fine_transfer_time check(status<>'TRANSFERRED' or transferred_at is not null);
drop index toll_fine_notices_queue;
create index toll_fine_notices_queue on public.toll_fine_notices(status,event_at desc);
create index toll_fine_registration_event on public.toll_fine_notices(upper(registration),event_at);

alter table public.notice_match_results drop constraint notice_match_results_confidence_check;
alter table public.notice_match_results drop constraint notice_match_results_match_status_check;
alter table public.notice_match_results drop constraint match_result_consistent;
update public.notice_match_results set confidence=case confidence when 'NONE' then 'NO_MATCH' else confidence end;
alter table public.notice_match_results
  add column matched_agreement_id uuid references public.agreements(id),
  add constraint notice_match_results_confidence_check check(confidence in ('HIGH','MEDIUM','LOW','NO_MATCH','AMBIGUOUS')),
  add constraint notice_match_results_match_status_check check(match_status in ('EXACT','NO_MATCH','AMBIGUOUS','INCONSISTENT'));

create or replace function app_private.preserve_notice_evidence() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'historical toll/fine evidence is immutable'; end $$;
create trigger notice_match_results_immutable before update or delete on public.notice_match_results for each row execute function app_private.preserve_notice_evidence();
create trigger notice_allocations_immutable before update or delete on public.notice_allocations for each row execute function app_private.preserve_notice_evidence();
create trigger notice_status_history_immutable before update or delete on public.notice_status_history for each row execute function app_private.preserve_notice_evidence();
create or replace function app_private.protect_original_toll_fine_import() returns trigger language plpgsql set search_path='' as $$
begin if new.original_import_data is distinct from old.original_import_data or new.source is distinct from old.source or new.external_reference is distinct from old.external_reference then raise exception 'original imported information is immutable'; end if; return new; end $$;
create trigger toll_fine_original_import_immutable before update on public.toll_fine_notices for each row execute function app_private.protect_original_toll_fine_import();

create table public.toll_fine_import_batches (
  id uuid primary key default gen_random_uuid(), source text not null check(btrim(source)<>''), file_name text not null,
  checksum text not null check(checksum ~ '^[a-f0-9]{64}$'), status text not null default 'PROCESSING' check(status in ('PROCESSING','COMPLETED','FAILED')),
  row_count integer not null default 0, accepted_count integer not null default 0, rejected_count integer not null default 0,
  imported_by uuid not null references public.staff_profiles(user_id), created_at timestamptz not null default now(), completed_at timestamptz,
  unique(source,checksum)
);
create table public.toll_fine_import_rows (
  id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.toll_fine_import_batches(id), row_number integer not null,
  raw_data jsonb not null check(jsonb_typeof(raw_data)='object'), row_checksum text not null,
  status text not null check(status in ('ACCEPTED','REJECTED','DUPLICATE')), notice_id uuid references public.toll_fine_notices(id),
  rejection_reason text, created_at timestamptz not null default now(), unique(batch_id,row_number)
);
alter table public.toll_fine_notices add constraint toll_fine_import_batch_fk foreign key(import_batch_id) references public.toll_fine_import_batches(id);
alter table public.toll_fine_import_batches enable row level security;
alter table public.toll_fine_import_rows enable row level security;
create policy staff_read_toll_fine_batches on public.toll_fine_import_batches for select to authenticated using(app_private.is_staff());
create policy staff_read_toll_fine_rows on public.toll_fine_import_rows for select to authenticated using(app_private.is_staff());
revoke all on public.toll_fine_import_batches,public.toll_fine_import_rows from anon,authenticated;
grant select on public.toll_fine_import_batches,public.toll_fine_import_rows to authenticated;

create or replace function app_private.match_notice(p_notice_id uuid,p_actor uuid) returns public.notice_match_results
language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices; r public.notice_match_results; c integer; chosen_assignment uuid; chosen_customer uuid; chosen_agreement uuid; ev jsonb; conf text; why text; inconsistent boolean;
begin
 select * into n from public.toll_fine_notices where id=p_notice_id for update; if not found then raise exception 'notice not found'; end if;
 if n.event_at is null or n.vehicle_id is null then c:=0; conf:='NO_MATCH'; why:='Missing event timestamp or registered vehicle'; ev:=jsonb_build_object('registration',n.registration,'event_at',n.event_at,'candidates','[]'::jsonb);
 else
   select count(*),coalesce(bool_or(x.registration_mismatch or x.invalid_period),false),coalesce(jsonb_agg(jsonb_build_object(
     'assignment_id',x.assignment_id,'customer_id',x.customer_id,'customer_name',x.customer_name,'agreement_id',x.agreement_id,
     'custody_start',x.custody_start,'custody_end',x.custody_end,'assignment_start',x.assigned_at,'assignment_end',x.returned_at,
     'pickup_actual_at',x.pickup_actual_at,'return_actual_at',x.return_actual_at,'vehicle_id',n.vehicle_id,'registration',n.registration)),'[]'::jsonb)
   into c,inconsistent,ev from (
     select a.id assignment_id,a.customer_id,c.full_name customer_name,a.assigned_at,a.returned_at,
       coalesce(p.actual_at,a.assigned_at) custody_start,coalesce(rr.actual_at,a.returned_at) custody_end,p.actual_at pickup_actual_at,rr.actual_at return_actual_at,
       ag.id agreement_id,upper(v.registration)<>upper(n.registration) registration_mismatch,
       coalesce(rr.actual_at,a.returned_at,'infinity'::timestamptz)<=coalesce(p.actual_at,a.assigned_at) invalid_period
     from public.vehicle_assignments a join public.vehicles v on v.id=a.vehicle_id join public.customers c on c.id=a.customer_id
     left join lateral(select actual_at from public.pickup_checklists where vehicle_id=a.vehicle_id and customer_id=a.customer_id and status='COMPLETED' order by actual_at desc nulls last limit 1) p on true
     left join lateral(select rc.actual_at from public.return_checklists rc where rc.assignment_id=a.id and rc.status='COMPLETED' order by rc.actual_at desc nulls last limit 1) rr on true
     left join lateral(select g.id from public.agreements g where g.vehicle_id=a.vehicle_id and g.customer_id=a.customer_id and n.event_at::date>=g.start_date and (g.end_date is null or n.event_at::date<=g.end_date) and g.status in ('ACTIVE','SUSPENDED','COMPLETED') order by (g.status='ACTIVE') desc,g.created_at desc limit 1) ag on true
     where a.vehicle_id=n.vehicle_id and n.event_at>=coalesce(p.actual_at,a.assigned_at) and (coalesce(rr.actual_at,a.returned_at) is null or n.event_at<coalesce(rr.actual_at,a.returned_at))
   ) x;
   if c=1 and not inconsistent then conf:='HIGH'; why:='Exactly one consistent custody period covered the event time and registration matched';
   elsif c>1 then conf:='AMBIGUOUS'; why:='Overlapping custody periods covered the event time';
   elsif inconsistent then conf:='LOW'; why:='Vehicle registration or custody timestamps are inconsistent';
   else conf:='NO_MATCH'; why:='No custody period covered the event time (assignment gap or no assignment)'; end if;
 end if;
 if conf='HIGH' then
   select (e->>'assignment_id')::uuid,(e->>'customer_id')::uuid,(e->>'agreement_id')::uuid into chosen_assignment,chosen_customer,chosen_agreement from jsonb_array_elements(ev) e limit 1;
 end if;
 insert into public.notice_match_results(notice_id,candidate_count,matched_assignment_id,matched_customer_id,matched_agreement_id,match_status,confidence,reason,evidence)
 values(n.id,c,chosen_assignment,chosen_customer,chosen_agreement,case when conf='HIGH' then 'EXACT' when conf='AMBIGUOUS' then 'AMBIGUOUS' when conf='LOW' then 'INCONSISTENT' else 'NO_MATCH' end,conf,why,
   jsonb_build_object('vehicle_id',n.vehicle_id,'registration',n.registration,'event_at',n.event_at,'amount',n.amount,'authority_provider',n.authority_provider,'reason',why,'candidates',ev)) returning * into r;
 update public.toll_fine_notices set status=case when conf='HIGH' then 'MATCHED' else 'NEEDS_REVIEW' end,
   matched_customer_id=chosen_customer,matched_assignment_id=chosen_assignment,matched_agreement_id=chosen_agreement,match_confidence=conf where id=n.id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,'TOLL_FINE_MATCH','toll_fine_notice',n.id,jsonb_build_object('match_result_id',r.id,'confidence',conf,'candidate_count',c));
 return r;
end $$;

create or replace function public.create_toll_fine_notice(p_notice_type text,p_external_reference text,p_vehicle_id uuid,p_registration_snapshot text,p_occurred_at timestamptz,p_issued_at timestamptz,p_amount numeric,p_source text,
  p_authority_provider text default null,p_notes text default null) returns public.toll_fine_notices language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_occurred_at is null then raise exception 'event date/time required' using errcode='22023'; end if;
 if not exists(select 1 from public.vehicles where id=p_vehicle_id) then raise exception 'vehicle not found'; end if;
 if nullif(btrim(p_registration_snapshot),'') is null then raise exception 'registration required'; end if;
 insert into public.toll_fine_notices(type,external_reference,vehicle_id,registration,event_at,issued_at,amount,source,authority_provider,notes,original_import_data)
 values(p_notice_type,nullif(btrim(p_external_reference),''),p_vehicle_id,upper(btrim(p_registration_snapshot)),p_occurred_at,p_issued_at,p_amount,btrim(p_source),nullif(btrim(p_authority_provider),''),nullif(btrim(p_notes),''),jsonb_build_object('entry_method','MANUAL','registration',p_registration_snapshot,'event_at',p_occurred_at,'amount',p_amount,'external_reference',p_external_reference,'authority_provider',p_authority_provider,'type',p_notice_type)) returning * into n;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTICE_CREATED','toll_fine_notice',n.id,jsonb_build_object('type',n.type,'source',n.source));
 perform app_private.match_notice(n.id,auth.uid()); select * into n from public.toll_fine_notices where id=n.id; return n;
end $$;

create or replace function public.review_notice_allocation(p_notice_id uuid,p_decision text,p_customer_id uuid,p_assignment_id uuid,p_reason text)
returns public.notice_allocations language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices; m public.notice_match_results; a public.notice_allocations; agreement_id uuid; decision_name text; new_status text;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if nullif(btrim(p_reason),'') is null then raise exception 'override reason required' using errcode='22023'; end if;
 select * into n from public.toll_fine_notices where id=p_notice_id for update; if not found then raise exception 'notice not found'; end if;
 select * into m from public.notice_match_results where notice_id=n.id order by attempted_at desc limit 1;
 if p_decision='CONFIRMED' then
   if m.confidence<>'HIGH' or p_customer_id is distinct from m.matched_customer_id or p_assignment_id is distinct from m.matched_assignment_id then raise exception 'confirmation must use high-confidence automated match'; end if;
   agreement_id:=m.matched_agreement_id; decision_name:='CONFIRMED'; new_status:='CONFIRMED';
 elsif p_decision='MANUALLY_ASSIGNED' then
   if p_customer_id is null then raise exception 'manual override requires customer'; end if;
   if p_assignment_id is not null and not exists(select 1 from public.vehicle_assignments where id=p_assignment_id and customer_id=p_customer_id and vehicle_id=n.vehicle_id) then raise exception 'assignment does not belong to customer and vehicle'; end if;
   select id into agreement_id from public.agreements where customer_id=p_customer_id and vehicle_id=n.vehicle_id and n.event_at::date>=start_date and (end_date is null or n.event_at::date<=end_date) order by created_at desc limit 1;
   decision_name:='MANUALLY_ASSIGNED'; new_status:='CONFIRMED';
 elsif p_decision='REJECTED' then decision_name:='REJECTED'; new_status:='NEEDS_REVIEW'; p_customer_id:=null; p_assignment_id:=null;
 else raise exception 'invalid allocation decision'; end if;
 insert into public.notice_allocations(notice_id,customer_id,assignment_id,decision,reviewer,reason,automated_match_result_id) values(n.id,p_customer_id,p_assignment_id,decision_name,auth.uid(),btrim(p_reason),m.id) returning * into a;
 update public.toll_fine_notices set status=new_status,matched_customer_id=p_customer_id,matched_assignment_id=p_assignment_id,matched_agreement_id=agreement_id,reviewed_by=auth.uid(),reviewed_at=now() where id=n.id;
 insert into public.notice_status_history(notice_id,from_status,to_status,actor,reason) values(n.id,n.status,new_status,auth.uid(),btrim(p_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),case when p_decision='MANUALLY_ASSIGNED' then 'TOLL_FINE_OVERRIDE' else 'TOLL_FINE_CONFIRM' end,'toll_fine_notice',n.id,jsonb_build_object('customer_id',p_customer_id,'assignment_id',p_assignment_id,'reason',btrim(p_reason),'match_result_id',m.id)); return a;
end $$;

create or replace function public.transition_toll_fine_notice(p_notice_id uuid,p_status text,p_reason text) returns public.toll_fine_notices language plpgsql security definer set search_path='' as $$
declare n public.toll_fine_notices; action_name text; old_status text;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if nullif(btrim(p_reason),'') is null then raise exception 'transition reason required'; end if;
 select * into n from public.toll_fine_notices where id=p_notice_id for update; if not found then raise exception 'notice not found'; end if; old_status:=n.status;
 if not ((n.status='CONFIRMED' and p_status in ('TRANSFER_PENDING','DISPUTED','CANCELLED')) or (n.status='TRANSFER_PENDING' and p_status in ('TRANSFERRED','DISPUTED','CANCELLED')) or (n.status='DISPUTED' and p_status in ('CONFIRMED','CANCELLED')) or (n.status='NEEDS_REVIEW' and p_status in ('DISPUTED','CANCELLED'))) then raise exception 'invalid toll/fine status transition'; end if;
 action_name:=case p_status when 'TRANSFER_PENDING' then 'TOLL_FINE_TRANSFER_PENDING' when 'TRANSFERRED' then 'TOLL_FINE_TRANSFERRED' when 'DISPUTED' then 'TOLL_FINE_DISPUTE' when 'CANCELLED' then 'TOLL_FINE_CANCELLED' else 'TOLL_FINE_CONFIRM' end;
 update public.toll_fine_notices set status=p_status,transferred_at=case when p_status='TRANSFERRED' then now() else transferred_at end where id=n.id returning * into n;
 insert into public.notice_status_history(notice_id,from_status,to_status,actor,reason) values(n.id,old_status,p_status,auth.uid(),btrim(p_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),action_name,'toll_fine_notice',n.id,jsonb_build_object('to',p_status,'reason',btrim(p_reason))); return n;
end $$;

create or replace function public.import_synthetic_toll_fine_csv(p_source text,p_file_name text,p_checksum text,p_rows jsonb)
returns public.toll_fine_import_batches language plpgsql security definer set search_path='' as $$
declare b public.toll_fine_import_batches; row_data jsonb; row_no integer:=0; accepted integer:=0; rejected integer:=0; duplicate_count integer:=0;
  vehicle uuid; notice public.toll_fine_notices; reason text; event_time timestamptz; row_amount numeric; row_type text; row_reference text; row_registration text;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_source<>'SYNTHETIC_CSV' then raise exception 'only SYNTHETIC_CSV imports are enabled' using errcode='22023'; end if;
 if p_checksum !~ '^[a-f0-9]{64}$' or jsonb_typeof(p_rows)<>'array' then raise exception 'invalid import checksum or rows'; end if;
 select * into b from public.toll_fine_import_batches where source=p_source and checksum=p_checksum;
 if found then return b; end if;
 insert into public.toll_fine_import_batches(source,file_name,checksum,imported_by) values(p_source,btrim(p_file_name),p_checksum,auth.uid()) returning * into b;
 for row_data in select value from jsonb_array_elements(p_rows) loop
   row_no:=row_no+1; reason:=null; vehicle:=null; event_time:=null; row_amount:=null;
   row_registration:=upper(btrim(coalesce(row_data->>'registration',''))); row_reference:=nullif(btrim(row_data->>'external_reference'),''); row_type:=upper(btrim(coalesce(row_data->>'type','')));
   begin event_time:=(row_data->>'event_at')::timestamptz; exception when others then reason:='Invalid or missing event_at'; end;
   begin row_amount:=(row_data->>'amount')::numeric; exception when others then reason:=coalesce(reason,'Invalid amount'); end;
   if row_registration='' then reason:=coalesce(reason,'Registration is required'); end if;
   if row_type not in ('TOLL','PARKING_FINE','SPEEDING_FINE','OTHER_INFRINGEMENT') then reason:=coalesce(reason,'Invalid type'); end if;
   if row_amount is null or row_amount<0 then reason:=coalesce(reason,'Amount must be zero or greater'); end if;
   select id into vehicle from public.vehicles where upper(registration)=row_registration;
   if vehicle is null then reason:=coalesce(reason,'Registration does not match a vehicle'); end if;
   if row_reference is not null and exists(select 1 from public.toll_fine_notices where source=p_source and external_reference=row_reference) then
     insert into public.toll_fine_import_rows(batch_id,row_number,raw_data,row_checksum,status,rejection_reason) values(b.id,row_no,row_data,md5(row_data::text),'DUPLICATE','Duplicate external reference'); duplicate_count:=duplicate_count+1;
   elsif reason is not null then
     insert into public.toll_fine_import_rows(batch_id,row_number,raw_data,row_checksum,status,rejection_reason) values(b.id,row_no,row_data,md5(row_data::text),'REJECTED',reason); rejected:=rejected+1;
   else
     insert into public.toll_fine_notices(source,external_reference,type,vehicle_id,registration,event_at,amount,authority_provider,status,original_import_data,import_batch_id)
     values(p_source,row_reference,row_type,vehicle,row_registration,event_time,row_amount,nullif(btrim(row_data->>'authority_provider'),''),'IMPORTED',row_data,b.id) returning * into notice;
     perform app_private.match_notice(notice.id,auth.uid());
     insert into public.toll_fine_import_rows(batch_id,row_number,raw_data,row_checksum,status,notice_id) values(b.id,row_no,row_data,md5(row_data::text),'ACCEPTED',notice.id); accepted:=accepted+1;
   end if;
 end loop;
 update public.toll_fine_import_batches set status='COMPLETED',row_count=row_no,accepted_count=accepted,rejected_count=rejected+duplicate_count,completed_at=now() where id=b.id returning * into b;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'TOLL_FINE_IMPORT','toll_fine_import_batch',b.id,jsonb_build_object('checksum',p_checksum,'accepted',accepted,'rejected',rejected,'duplicates',duplicate_count));
 return b;
end $$;

create or replace function public.refresh_toll_fine_owner_attention(p_high_value numeric default 250,p_overdue_days integer default 7) returns integer
language plpgsql security definer set search_path='' as $$
declare notice_record public.toll_fine_notices; total integer:=0;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.operational_exceptions e set status='RESOLVED',resolved_at=now(),resolution_note='Automatically cleared by toll/fine lifecycle',updated_at=now()
 where e.entity_type='toll_fine_notice' and e.status<>'RESOLVED' and not exists(select 1 from public.toll_fine_notices current_notice where current_notice.id=e.entity_id and (
   (e.exception_type='HIGH_VALUE_FINE' and current_notice.type<>'TOLL' and current_notice.amount>=p_high_value and current_notice.status in ('IMPORTED','MATCHED','NEEDS_REVIEW')) or
   (e.exception_type='AMBIGUOUS_TOLL_FINE' and current_notice.match_confidence='AMBIGUOUS' and current_notice.status='NEEDS_REVIEW') or
   (e.exception_type='DISPUTED_NOTICE' and current_notice.status='DISPUTED') or
   (e.exception_type='OVERDUE_TOLL_FINE_TRANSFER' and current_notice.status='TRANSFER_PENDING' and current_notice.updated_at<now()-make_interval(days=>p_overdue_days)) or
   (e.exception_type='TOLL_FINE_CUSTODY_INCONSISTENCY' and current_notice.match_confidence='LOW' and current_notice.status='NEEDS_REVIEW')));
 for notice_record in select * from public.toll_fine_notices where
   (type<>'TOLL' and amount>=p_high_value and status in ('IMPORTED','MATCHED','NEEDS_REVIEW')) or match_confidence='AMBIGUOUS' or status='DISPUTED' or
   (status='TRANSFER_PENDING' and updated_at<now()-make_interval(days=>p_overdue_days)) or (match_confidence='LOW' and status='NEEDS_REVIEW')
 loop
   perform app_private.upsert_exception(
     case when notice_record.status='DISPUTED' then 'DISPUTED_NOTICE' when notice_record.status='TRANSFER_PENDING' then 'OVERDUE_TOLL_FINE_TRANSFER' when notice_record.match_confidence='AMBIGUOUS' then 'AMBIGUOUS_TOLL_FINE' when notice_record.match_confidence='LOW' then 'TOLL_FINE_CUSTODY_INCONSISTENCY' else 'HIGH_VALUE_FINE' end,
     case when notice_record.amount>=p_high_value then 'HIGH' else 'MEDIUM' end,'toll_fine_notice',notice_record.id,
     'toll-fine-attention:'||notice_record.id::text,
     case when notice_record.status='DISPUTED' then 'Disputed fine requires attention' when notice_record.status='TRANSFER_PENDING' then 'Liability transfer is overdue' when notice_record.match_confidence='AMBIGUOUS' then 'Driver custody is ambiguous' when notice_record.match_confidence='LOW' then 'Assignment history is inconsistent' else 'High-value fine is unresolved' end,
     jsonb_build_object('registration',notice_record.registration,'amount',notice_record.amount,'status',notice_record.status),true,auth.uid()); total:=total+1;
 end loop;
 for notice_record in select distinct on (registration) * from public.toll_fine_notices x where x.status='NEEDS_REVIEW' and x.match_confidence='NO_MATCH' and (select count(*) from public.toll_fine_notices y where upper(y.registration)=upper(x.registration) and y.status='NEEDS_REVIEW' and y.match_confidence='NO_MATCH')>=3 order by registration,event_at desc loop
   perform app_private.upsert_exception('REPEATED_UNMATCHED_TOLL_FINE','HIGH','toll_fine_notice',notice_record.id,'repeated-unmatched:'||upper(notice_record.registration),'Repeated unmatched toll/fine events for vehicle',jsonb_build_object('registration',notice_record.registration),true,auth.uid()); total:=total+1;
 end loop;
 return total;
end $$;

-- Customer-facing projection is intentionally empty until legal/business approval.
create or replace view public.customer_safe_toll_fines with (security_barrier=true) as
select id,type,event_at,amount,status from public.toll_fine_notices where false;
revoke all on public.customer_safe_toll_fines from anon,authenticated;

drop function public.create_toll_fine_notice(text,text,uuid,text,timestamptz,timestamptz,numeric,text);
revoke all on function public.create_toll_fine_notice(text,text,uuid,text,timestamptz,timestamptz,numeric,text,text,text) from public;
grant execute on function public.create_toll_fine_notice(text,text,uuid,text,timestamptz,timestamptz,numeric,text,text,text) to authenticated;
revoke all on function public.import_synthetic_toll_fine_csv(text,text,text,jsonb),public.refresh_toll_fine_owner_attention(numeric,integer) from public;
grant execute on function public.import_synthetic_toll_fine_csv(text,text,text,jsonb),public.refresh_toll_fine_owner_attention(numeric,integer) to authenticated;

comment on view public.customer_safe_toll_fines is 'Future minimal customer-safe projection. Deliberately returns no rows and has no customer grant.';
comment on table public.toll_fine_import_batches is 'Synthetic provider-neutral CSV staging only. No external provider connection.';
