-- Staged bank/PayID reconciliation. Synthetic CSV input only; no bank connection or credentials.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED',
  'AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED',
  'PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED',
  'AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED',
  'EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED',
  'CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED',
  'RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED',
  'VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED',
  'NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN',
  'MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED',
  'MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY',
  'BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED',
  'BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED'
));

alter table public.operational_exceptions drop constraint operational_exceptions_exception_type_check;
alter table public.operational_exceptions add constraint operational_exceptions_exception_type_check check (exception_type in (
  'OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','AGREEMENT_AWAITING_SIGNATURE','UNALLOCATED_FUNDS',
  'PAYMENT_ALLOCATION','SCHEDULE_EXTENSION_FAILURE','VEHICLE_SWAP_FAILURE','VEHICLE_STATE_INCONSISTENCY',
  'CUSTOMER_APPROVAL','PICKUP_PREREQUISITE','RETURN_PREREQUISITE','LICENCE_EXPIRY','REGISTRATION_EXPIRY',
  'RWC_EXPIRY','SERVICE_DUE','SERVICE_OVERDUE','VEHICLE_OFF_ROAD_TOO_LONG','UNMATCHED_TOLL_FINE',
  'AMBIGUOUS_TOLL_FINE','DISPUTED_NOTICE','BROKEN_PAYMENT_PROMISE','OVERDUE_PAYMENT_ESCALATION',
  'REMINDER_WORKFLOW_FAILURE','MESSAGE_MISSING_CONTACT','MESSAGE_INVALID_CONTACT','MESSAGE_REPEATED_FAILURE','MESSAGE_STUCK_QUEUE',
  'UNMATCHED_BANK_RECEIPT','AMBIGUOUS_BANK_MATCH','SUSPICIOUS_BANK_DUPLICATE','UNUSUALLY_LARGE_RECEIPT',
  'UNRESOLVED_UNALLOCATED_AMOUNT','BANK_REVERSAL_REVIEW','BANK_IMPORT_BATCH_FAILURE'
));

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('SYNTHETIC_CSV')),
  source_identifier text not null check (btrim(source_identifier) <> '' and length(source_identifier) <= 255),
  checksum text not null check (checksum ~ '^[a-f0-9]{64}$'),
  row_count integer not null check (row_count >= 0),
  imported_by uuid not null references public.staff_profiles(user_id),
  imported_at timestamptz not null default now(),
  status text not null check (status in ('COMPLETED','COMPLETED_WITH_REJECTIONS','FAILED')),
  result jsonb not null default '{}'::jsonb check (jsonb_typeof(result) = 'object'),
  unique (source, checksum)
);

create table public.imported_bank_transactions (
  id uuid primary key default gen_random_uuid(),
  external_transaction_id text not null check (btrim(external_transaction_id) <> '' and length(external_transaction_id) <= 255),
  source text not null check (source = 'SYNTHETIC_CSV'),
  transaction_date date not null,
  received_at timestamptz not null,
  amount numeric(12,2) not null check (amount <> 0),
  description text check (length(description) <= 1000),
  payer_name_raw text check (length(payer_name_raw) <= 500),
  reference_raw text check (length(reference_raw) <= 500),
  status text not null default 'NEW' check (status in ('NEW','MATCHED','REVIEW_REQUIRED','ALLOCATED','IGNORED','REVERSED')),
  imported_at timestamptz not null default now(),
  import_batch_id uuid not null references public.import_batches(id),
  reverses_imported_bank_transaction_id uuid references public.imported_bank_transactions(id),
  unique (source, external_transaction_id),
  constraint imported_bank_time_valid check (received_at::date >= transaction_date - 2),
  constraint imported_reversal_shape check ((amount < 0 and reverses_imported_bank_transaction_id is not null) or (amount > 0 and reverses_imported_bank_transaction_id is null))
);
create index imported_bank_queue on public.imported_bank_transactions(status,transaction_date desc);
create index imported_bank_batch on public.imported_bank_transactions(import_batch_id);
create unique index one_imported_reversal on public.imported_bank_transactions(reverses_imported_bank_transaction_id) where reverses_imported_bank_transaction_id is not null;

create table public.bank_match_runs (
  id uuid primary key default gen_random_uuid(),
  imported_bank_transaction_id uuid not null references public.imported_bank_transactions(id),
  confidence text not null check (confidence in ('HIGH','MEDIUM','LOW','NO_MATCH','AMBIGUOUS')),
  candidate_count integer not null check (candidate_count >= 0),
  suggested_customer_id uuid references public.customers(id),
  suggested_agreement_id uuid references public.agreements(id),
  score integer not null check (score between 0 and 100),
  reason text not null check (btrim(reason) <> ''),
  evidence jsonb not null default '{}'::jsonb check (jsonb_typeof(evidence) = 'object'),
  generated_at timestamptz not null default now(),
  generated_by uuid not null references public.staff_profiles(user_id),
  constraint match_suggestion_pair check ((suggested_customer_id is null) = (suggested_agreement_id is null))
);
create index bank_match_history on public.bank_match_runs(imported_bank_transaction_id,generated_at desc);

create table public.bank_match_candidates (
  id uuid primary key default gen_random_uuid(),
  match_run_id uuid not null references public.bank_match_runs(id),
  customer_id uuid not null references public.customers(id),
  agreement_id uuid not null references public.agreements(id),
  score integer not null check (score between 0 and 100),
  confidence text not null check (confidence in ('HIGH','MEDIUM','LOW')),
  reason text not null,
  evidence jsonb not null check (jsonb_typeof(evidence) = 'object'),
  unique(match_run_id,agreement_id)
);

create table public.bank_reconciliation_actions (
  id uuid primary key default gen_random_uuid(),
  imported_bank_transaction_id uuid not null references public.imported_bank_transactions(id),
  action text not null check (action in ('AUTO_ALLOCATED','CONFIRMED','OVERRIDDEN','SPLIT','IGNORED','REVERSED')),
  actor uuid not null references public.staff_profiles(user_id),
  reason text not null check (btrim(reason) <> '' and length(reason) <= 500),
  match_run_id uuid references public.bank_match_runs(id),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  created_at timestamptz not null default now()
);
create index bank_reconciliation_history on public.bank_reconciliation_actions(imported_bank_transaction_id,created_at desc);

create table public.bank_payment_postings (
  id uuid primary key default gen_random_uuid(),
  imported_bank_transaction_id uuid not null references public.imported_bank_transactions(id),
  agreement_id uuid not null references public.agreements(id),
  payment_transaction_id uuid not null unique references public.payment_transactions(id),
  amount numeric(12,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique(imported_bank_transaction_id,agreement_id)
);
create index bank_postings_import on public.bank_payment_postings(imported_bank_transaction_id);

create or replace function app_private.reject_reconciliation_ledger_mutation()
returns trigger language plpgsql set search_path='' as $$ begin
  raise exception 'bank reconciliation history is immutable' using errcode='42501';
end $$;
create trigger bank_match_runs_immutable before update or delete on public.bank_match_runs for each row execute function app_private.reject_reconciliation_ledger_mutation();
create trigger bank_match_candidates_immutable before update or delete on public.bank_match_candidates for each row execute function app_private.reject_reconciliation_ledger_mutation();
create trigger bank_actions_immutable before update or delete on public.bank_reconciliation_actions for each row execute function app_private.reject_reconciliation_ledger_mutation();
create trigger bank_postings_immutable before update or delete on public.bank_payment_postings for each row execute function app_private.reject_reconciliation_ledger_mutation();

alter table public.import_batches enable row level security;
alter table public.imported_bank_transactions enable row level security;
alter table public.bank_match_runs enable row level security;
alter table public.bank_match_candidates enable row level security;
alter table public.bank_reconciliation_actions enable row level security;
alter table public.bank_payment_postings enable row level security;
create policy staff_read_import_batches on public.import_batches for select to authenticated using(app_private.is_staff());
create policy staff_read_imported_bank on public.imported_bank_transactions for select to authenticated using(app_private.is_staff());
create policy staff_read_bank_match_runs on public.bank_match_runs for select to authenticated using(app_private.is_staff());
create policy staff_read_bank_candidates on public.bank_match_candidates for select to authenticated using(app_private.is_staff());
create policy staff_read_bank_actions on public.bank_reconciliation_actions for select to authenticated using(app_private.is_staff());
create policy staff_read_bank_postings on public.bank_payment_postings for select to authenticated using(app_private.is_staff());
revoke all on public.import_batches,public.imported_bank_transactions,public.bank_match_runs,public.bank_match_candidates,public.bank_reconciliation_actions,public.bank_payment_postings from anon,authenticated;
grant select on public.import_batches,public.imported_bank_transactions,public.bank_match_runs,public.bank_match_candidates,public.bank_reconciliation_actions,public.bank_payment_postings to authenticated;

create or replace function app_private.bank_match_candidate_values(p_transaction_id uuid)
returns table(agreement_id uuid,customer_id uuid,score int,amount_exact bool,weekly_exact bool,reference_match bool,name_match bool,phone_match bool,due_window bool,outstanding numeric)
language sql stable security definer set search_path='' as $$
  select a.id,a.customer_id,
    least(100,(case when abs(t.amount-s.outstanding) < .005 then 35 else 0 end)+(case when mod(t.amount,a.weekly_amount)=0 then 15 else 0 end)+
      (case when lower(coalesce(t.reference_raw,'')) like '%'||lower(a.id::text)||'%' then 45 else 0 end)+
      (case when lower(btrim(coalesce(t.payer_name_raw,'')))=lower(btrim(c.full_name)) then 35 else 0 end)+
      (case when length(regexp_replace(coalesce(c.phone,''),'\D','','g'))>=6 and regexp_replace(coalesce(t.reference_raw,''),'\D','','g') like '%'||regexp_replace(c.phone,'\D','','g')||'%' then 45 else 0 end)+
      (case when exists(select 1 from public.payment_schedule_items p where p.agreement_id=a.id and p.amount_paid<p.amount_due and p.status<>'WAIVED' and p.due_date between t.transaction_date-14 and t.transaction_date+14) then 10 else 0 end))::int,
    abs(t.amount-s.outstanding)<.005,mod(t.amount,a.weekly_amount)=0,
    lower(coalesce(t.reference_raw,'')) like '%'||lower(a.id::text)||'%',
    lower(btrim(coalesce(t.payer_name_raw,'')))=lower(btrim(c.full_name)),
    length(regexp_replace(coalesce(c.phone,''),'\D','','g'))>=6 and regexp_replace(coalesce(t.reference_raw,''),'\D','','g') like '%'||regexp_replace(c.phone,'\D','','g')||'%',
    exists(select 1 from public.payment_schedule_items p where p.agreement_id=a.id and p.amount_paid<p.amount_due and p.status<>'WAIVED' and p.due_date between t.transaction_date-14 and t.transaction_date+14),s.outstanding
  from public.imported_bank_transactions t cross join public.agreements a join public.customers c on c.id=a.customer_id
  cross join lateral(select coalesce(sum(p.amount_due-p.amount_paid) filter(where p.status<>'WAIVED'),0) outstanding from public.payment_schedule_items p where p.agreement_id=a.id) s
  where t.id=p_transaction_id and a.status in ('ACTIVE','SUSPENDED') and s.outstanding>0
$$;

create or replace function app_private.run_bank_match(p_transaction_id uuid,p_actor uuid)
returns public.bank_match_runs language plpgsql security definer set search_path='' as $$
declare t public.imported_bank_transactions; r public.bank_match_runs; top_score int:=0; top_count int:=0; candidate_count int:=0; top_agreement uuid; top_customer uuid; conf text; why text;
begin
  select * into t from public.imported_bank_transactions where id=p_transaction_id for update;
  if not found or t.amount <= 0 then raise exception 'positive imported transaction not found'; end if;
  select count(*),coalesce(max(score),0) into candidate_count,top_score from app_private.bank_match_candidate_values(t.id) where score>=20;
  select count(*) into top_count from app_private.bank_match_candidate_values(t.id) where score=top_score and score>=20;
  if candidate_count=0 then conf:='NO_MATCH'; why:='No active agreement produced matching evidence';
  elsif top_count>1 then conf:='AMBIGUOUS'; why:='Multiple agreements share the highest score';
  else
    select agreement_id,customer_id into top_agreement,top_customer from app_private.bank_match_candidate_values(t.id) where score=top_score limit 1;
    conf:=case when top_score>=85 and exists(select 1 from app_private.bank_match_candidate_values(t.id) where agreement_id=top_agreement and amount_exact and (reference_match or phone_match or name_match)) then 'HIGH' when top_score>=55 then 'MEDIUM' else 'LOW' end;
    why:=case conf when 'HIGH' then 'Unique deterministic identifier and exact outstanding amount' when 'MEDIUM' then 'Useful evidence requires staff confirmation' else 'Weak evidence requires staff review' end;
  end if;
  insert into public.bank_match_runs(imported_bank_transaction_id,confidence,candidate_count,suggested_customer_id,suggested_agreement_id,score,reason,evidence,generated_by)
  values(t.id,conf,candidate_count,top_customer,top_agreement,top_score,why,jsonb_build_object('algorithm_version','v1','due_window_days',14,'candidate_threshold',20),p_actor) returning * into r;
  insert into public.bank_match_candidates(match_run_id,customer_id,agreement_id,score,confidence,reason,evidence)
  select r.id,c.customer_id,c.agreement_id,c.score,case when c.score>=85 then 'HIGH' when c.score>=55 then 'MEDIUM' else 'LOW' end,
    concat_ws('; ',case when amount_exact then 'exact outstanding amount' end,case when weekly_exact then 'weekly amount multiple' end,case when reference_match then 'agreement reference' end,case when name_match then 'exact payer/customer name' end,case when phone_match then 'customer phone reference' end,case when due_window then 'obligation in due-date window' end),
    jsonb_build_object('amount_exact',amount_exact,'weekly_amount_multiple',weekly_exact,'reference_match',reference_match,'payer_name_match',name_match,'phone_match',phone_match,'due_window',due_window,'outstanding',outstanding)
  from app_private.bank_match_candidate_values(t.id) c where c.score>=20 order by c.score desc;
  update public.imported_bank_transactions set status=case when conf='HIGH' then 'MATCHED' else 'REVIEW_REQUIRED' end where id=t.id;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,'BANK_MATCH_GENERATED','imported_bank_transaction',t.id,jsonb_build_object('confidence',conf,'candidate_count',candidate_count,'score',top_score));
  if conf='NO_MATCH' then perform app_private.upsert_exception('UNMATCHED_BANK_RECEIPT','MEDIUM','imported_bank_transaction',t.id,'bank-unmatched:'||t.id,'Imported receipt has no plausible agreement match','{}',false,p_actor);
  elsif conf='AMBIGUOUS' then perform app_private.upsert_exception('AMBIGUOUS_BANK_MATCH','HIGH','imported_bank_transaction',t.id,'bank-ambiguous:'||t.id,'Imported receipt has multiple equally ranked matches',jsonb_build_object('candidate_count',candidate_count),false,p_actor); end if;
  if t.amount>=1000 then perform app_private.upsert_exception('UNUSUALLY_LARGE_RECEIPT','HIGH','imported_bank_transaction',t.id,'bank-large:'||t.id,'Imported receipt exceeds the staged review threshold',jsonb_build_object('amount',t.amount),true,p_actor); end if;
  return r;
end $$;

create or replace function public.import_synthetic_bank_csv(p_source_identifier text,p_checksum text,p_rows jsonb)
returns public.import_batches language plpgsql security definer set search_path='' as $$
declare b public.import_batches; row jsonb; t public.imported_bank_transactions; inserted_count int:=0; duplicate_count int:=0; rejected_count int:=0;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if btrim(coalesce(p_source_identifier,''))='' or p_checksum !~ '^[a-f0-9]{64}$' or jsonb_typeof(p_rows)<>'array' then raise exception 'invalid synthetic import' using errcode='22023'; end if;
  select * into b from public.import_batches where source='SYNTHETIC_CSV' and checksum=p_checksum;
  if found then return b; end if;
  insert into public.import_batches(source,source_identifier,checksum,row_count,imported_by,status)
  values('SYNTHETIC_CSV',btrim(p_source_identifier),p_checksum,jsonb_array_length(p_rows),auth.uid(),'COMPLETED') returning * into b;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'BANK_IMPORT_BATCH_CREATED','import_batch',b.id,jsonb_build_object('source','SYNTHETIC_CSV','row_count',jsonb_array_length(p_rows)));
  for row in select value from jsonb_array_elements(p_rows) loop
    begin
      if coalesce(row->>'external_transaction_id','')='' or (row->>'amount')::numeric<=0 then raise exception 'invalid row'; end if;
      insert into public.imported_bank_transactions(external_transaction_id,source,transaction_date,received_at,amount,description,payer_name_raw,reference_raw,import_batch_id)
      values(row->>'external_transaction_id','SYNTHETIC_CSV',(row->>'transaction_date')::date,(row->>'received_at')::timestamptz,(row->>'amount')::numeric,row->>'description',row->>'payer_name_raw',row->>'reference_raw',b.id)
      on conflict(source,external_transaction_id) do nothing returning * into t;
      if t.id is null then duplicate_count:=duplicate_count+1;
        perform app_private.upsert_exception('SUSPICIOUS_BANK_DUPLICATE','MEDIUM','import_batch',b.id,'bank-duplicate:'||encode(extensions.digest('SYNTHETIC_CSV:'||(row->>'external_transaction_id'),'sha256'),'hex'),'Duplicate external transaction was not imported',jsonb_build_object('external_transaction_id',row->>'external_transaction_id'),false,auth.uid());
      else inserted_count:=inserted_count+1;
        insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'BANK_TRANSACTION_IMPORTED','imported_bank_transaction',t.id,jsonb_build_object('source','SYNTHETIC_CSV','import_batch_id',b.id));
        perform app_private.run_bank_match(t.id,auth.uid());
      end if;
      t:=null;
    exception when others then rejected_count:=rejected_count+1; end;
  end loop;
  update public.import_batches set status=case when rejected_count>0 then 'COMPLETED_WITH_REJECTIONS' else 'COMPLETED' end,result=jsonb_build_object('inserted',inserted_count,'duplicates',duplicate_count,'rejected',rejected_count) where id=b.id returning * into b;
  return b;
exception when others then
  if b.id is not null then update public.import_batches set status='FAILED',result=jsonb_build_object('error','Import failed validation') where id=b.id; perform app_private.upsert_exception('BANK_IMPORT_BATCH_FAILURE','HIGH','import_batch',b.id,'bank-import-failed:'||b.id,'Synthetic import batch failed','{}',true,auth.uid()); end if;
  raise;
end $$;

create or replace function public.record_synthetic_bank_import_failure(p_source_identifier text,p_checksum text,p_row_count integer default 0)
returns public.import_batches language plpgsql security definer set search_path='' as $$ declare b public.import_batches;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if btrim(coalesce(p_source_identifier,''))='' or p_checksum !~ '^[a-f0-9]{64}$' then raise exception 'invalid failed import metadata' using errcode='22023'; end if;
  insert into public.import_batches(source,source_identifier,checksum,row_count,imported_by,status,result)
  values('SYNTHETIC_CSV',btrim(p_source_identifier),p_checksum,greatest(coalesce(p_row_count,0),0),auth.uid(),'FAILED',jsonb_build_object('error','Synthetic CSV validation failed'))
  on conflict(source,checksum) do update set source_identifier=excluded.source_identifier returning * into b;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'BANK_IMPORT_BATCH_CREATED','import_batch',b.id,jsonb_build_object('source','SYNTHETIC_CSV','status','FAILED','row_count',b.row_count));
  perform app_private.upsert_exception('BANK_IMPORT_BATCH_FAILURE','HIGH','import_batch',b.id,'bank-import-failed:'||b.id,'Synthetic import batch failed validation','{}',true,auth.uid());
  return b;
end $$;

create or replace function public.reconcile_bank_transaction(p_transaction_id uuid,p_allocations jsonb,p_reason text,p_match_run_id uuid default null)
returns public.imported_bank_transactions language plpgsql security definer set search_path='' as $$
declare t public.imported_bank_transactions; x jsonb; requested numeric:=0; posted numeric:=0; financial_unallocated numeric:=0; payment public.payment_transactions; action_name text; allocation_count int; suggested uuid;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if btrim(coalesce(p_reason,''))='' or jsonb_typeof(p_allocations)<>'array' or jsonb_array_length(p_allocations)=0 then raise exception 'allocation and reason are required' using errcode='22023'; end if;
  select * into t from public.imported_bank_transactions where id=p_transaction_id and amount>0 for update;
  if not found then raise exception 'bank receipt not found'; end if;
  if exists(select 1 from public.bank_payment_postings where imported_bank_transaction_id=t.id) then raise exception 'bank receipt already financially posted'; end if;
  select count(*),coalesce(sum((value->>'amount')::numeric),0) into allocation_count,requested from jsonb_array_elements(p_allocations);
  if requested<=0 or requested>t.amount then raise exception 'allocated amount must be positive and cannot exceed receipt' using errcode='22023'; end if;
  select suggested_agreement_id into suggested from public.bank_match_runs where id=p_match_run_id and imported_bank_transaction_id=t.id;
  for x in select value from jsonb_array_elements(p_allocations) loop
    if (x->>'amount')::numeric<=0 then raise exception 'split amounts must be positive'; end if;
    payment:=public.record_manual_payment((x->>'agreement_id')::uuid,(x->>'amount')::numeric,t.received_at,t.reference_raw,'Staged synthetic bank reconciliation '||t.external_transaction_id);
    insert into public.bank_payment_postings(imported_bank_transaction_id,agreement_id,payment_transaction_id,amount) values(t.id,(x->>'agreement_id')::uuid,payment.id,(x->>'amount')::numeric);
    posted:=posted+(x->>'amount')::numeric;
    financial_unallocated:=financial_unallocated+payment.unallocated_amount;
  end loop;
  update public.reminder_actions r set status='CANCELLED' where r.status='QUEUED' and not exists(select 1 from public.agreement_payment_summary s where s.agreement_id=r.agreement_id and s.overdue_amount>0);
  perform app_private.sync_payment_deliveries(current_date,auth.uid());
  action_name:=case when allocation_count>1 then 'SPLIT' when suggested is not null and suggested=(p_allocations->0->>'agreement_id')::uuid then 'CONFIRMED' else 'OVERRIDDEN' end;
  update public.imported_bank_transactions set status=case when posted=t.amount then 'ALLOCATED' else 'REVIEW_REQUIRED' end where id=t.id returning * into t;
  insert into public.bank_reconciliation_actions(imported_bank_transaction_id,action,actor,reason,match_run_id,details) values(t.id,action_name,auth.uid(),btrim(p_reason),p_match_run_id,jsonb_build_object('allocations',p_allocations,'unposted_amount',t.amount-posted,'financial_unallocated_amount',financial_unallocated));
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),case when action_name='OVERRIDDEN' then 'BANK_MANUAL_MATCH_OVERRIDE' else 'BANK_TRANSACTION_ALLOCATED' end,'imported_bank_transaction',t.id,jsonb_build_object('allocation_count',allocation_count,'allocated_amount',posted,'unposted_amount',t.amount-posted,'financial_unallocated_amount',financial_unallocated));
  if t.amount>posted or financial_unallocated>0 then perform app_private.upsert_exception('UNRESOLVED_UNALLOCATED_AMOUNT','HIGH','imported_bank_transaction',t.id,'bank-unallocated:'||t.id,'Bank receipt retains an unresolved unallocated balance',jsonb_build_object('unposted_amount',t.amount-posted,'financial_unallocated_amount',financial_unallocated),true,auth.uid()); end if;
  return t;
end $$;

create or replace function public.auto_allocate_bank_transaction(p_transaction_id uuid)
returns public.imported_bank_transactions language plpgsql security definer set search_path='' as $$
declare m public.bank_match_runs; t public.imported_bank_transactions;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  select * into m from public.bank_match_runs where imported_bank_transaction_id=p_transaction_id order by generated_at desc limit 1;
  if not found or m.confidence<>'HIGH' or m.suggested_agreement_id is null then raise exception 'only a HIGH confidence match can auto-allocate'; end if;
  t:=public.reconcile_bank_transaction(p_transaction_id,jsonb_build_array(jsonb_build_object('agreement_id',m.suggested_agreement_id,'amount',(select amount from public.imported_bank_transactions where id=p_transaction_id))),'High-confidence deterministic match',m.id);
  insert into public.bank_reconciliation_actions(imported_bank_transaction_id,action,actor,reason,match_run_id) values(t.id,'AUTO_ALLOCATED',auth.uid(),'High-confidence deterministic match',m.id);
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'BANK_AUTO_ALLOCATED','imported_bank_transaction',t.id,jsonb_build_object('match_run_id',m.id,'score',m.score));
  return t;
end $$;

create or replace function public.ignore_bank_transaction(p_transaction_id uuid,p_reason text)
returns public.imported_bank_transactions language plpgsql security definer set search_path='' as $$ declare t public.imported_bank_transactions;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if btrim(coalesce(p_reason,''))='' then raise exception 'ignore reason is required' using errcode='22023'; end if;
 select * into t from public.imported_bank_transactions where id=p_transaction_id for update; if not found or t.status in ('ALLOCATED','REVERSED') then raise exception 'transaction cannot be ignored'; end if;
 update public.imported_bank_transactions set status='IGNORED' where id=t.id returning * into t;
 insert into public.bank_reconciliation_actions(imported_bank_transaction_id,action,actor,reason) values(t.id,'IGNORED',auth.uid(),btrim(p_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'BANK_TRANSACTION_IGNORED','imported_bank_transaction',t.id,'{}'); return t; end $$;

create or replace function public.reverse_bank_reconciliation(p_transaction_id uuid,p_reason text)
returns public.imported_bank_transactions language plpgsql security definer set search_path='' as $$ declare t public.imported_bank_transactions; p record;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if btrim(coalesce(p_reason,''))='' then raise exception 'reversal reason is required' using errcode='22023'; end if;
 select * into t from public.imported_bank_transactions where id=p_transaction_id for update; if not found or t.status<>'ALLOCATED' then raise exception 'allocated bank receipt not found'; end if;
 for p in select * from public.bank_payment_postings where imported_bank_transaction_id=t.id loop perform public.reverse_manual_payment(p.payment_transaction_id,btrim(p_reason)); end loop;
 update public.imported_bank_transactions set status='REVERSED' where id=t.id returning * into t;
 insert into public.bank_reconciliation_actions(imported_bank_transaction_id,action,actor,reason) values(t.id,'REVERSED',auth.uid(),btrim(p_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'BANK_RECONCILIATION_REVERSED','imported_bank_transaction',t.id,jsonb_build_object('payment_count',(select count(*) from public.bank_payment_postings where imported_bank_transaction_id=t.id)));
 perform app_private.upsert_exception('BANK_REVERSAL_REVIEW','HIGH','imported_bank_transaction',t.id,'bank-reversal:'||t.id,'Reversed bank reconciliation requires staff review','{}',true,auth.uid()); return t; end $$;

revoke all on function app_private.bank_match_candidate_values(uuid),app_private.run_bank_match(uuid,uuid) from public,anon,authenticated;
revoke all on function public.import_synthetic_bank_csv(text,text,jsonb),public.record_synthetic_bank_import_failure(text,text,integer),public.reconcile_bank_transaction(uuid,jsonb,text,uuid),public.auto_allocate_bank_transaction(uuid),public.ignore_bank_transaction(uuid,text),public.reverse_bank_reconciliation(uuid,text) from public;
grant execute on function public.import_synthetic_bank_csv(text,text,jsonb),public.record_synthetic_bank_import_failure(text,text,integer),public.reconcile_bank_transaction(uuid,jsonb,text,uuid),public.auto_allocate_bank_transaction(uuid),public.ignore_bank_transaction(uuid,text),public.reverse_bank_reconciliation(uuid,text) to authenticated;

comment on table public.imported_bank_transactions is 'Raw, durable staged synthetic bank transactions. No bank credentials or production feed.';
comment on function public.import_synthetic_bank_csv(text,text,jsonb) is 'Imports server-parsed synthetic CSV rows idempotently. This boundary must remain disabled for real banking files in production.';
