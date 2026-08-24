-- Veera V2 agreements and manual weekly payment tracking.
-- Operational tracking only: no collection, bank reconciliation, or ownership transfer.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED', 'VEHICLE_RETURNED', 'VEHICLE_SWAPPED', 'VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED', 'CUSTOMER_EDITED', 'CUSTOMER_STATUS_CHANGED',
  'VEHICLE_CREATED', 'VEHICLE_EDITED', 'STAFF_ACCESS_CHANGED',
  'AGREEMENT_CREATED', 'AGREEMENT_ACTIVATED', 'AGREEMENT_SUSPENDED',
  'AGREEMENT_COMPLETED', 'AGREEMENT_CANCELLED', 'PAYMENT_MANUALLY_RECORDED',
  'PAYMENT_REVERSED', 'PAYMENT_ADJUSTED', 'SCHEDULE_GENERATED'
));

create table public.agreements (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers (id),
  vehicle_id uuid references public.vehicles (id),
  agreement_type text not null check (agreement_type in ('WEEKLY_RENTAL','RENT_TO_OWN','SHORT_TERM')),
  status text not null default 'DRAFT' check (status in ('DRAFT','PENDING_SIGNATURE','ACTIVE','SUSPENDED','COMPLETED','CANCELLED')),
  start_date date not null,
  end_date date,
  first_due_date date not null,
  weekly_amount numeric(12,2) not null check (weekly_amount > 0),
  deposit_amount numeric(12,2) not null default 0 check (deposit_amount >= 0),
  agreed_total_amount numeric(12,2),
  agreed_payment_count integer,
  external_contract_provider text,
  external_contract_id text,
  signed_at timestamptz,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agreement_dates_valid check (end_date is null or end_date >= start_date),
  constraint agreement_first_due_valid check (first_due_date >= start_date and (end_date is null or first_due_date <= end_date)),
  constraint agreement_rto_terms check (
    agreement_type <> 'RENT_TO_OWN'
    or ((agreed_total_amount is not null and agreed_total_amount > 0)
      or (agreed_payment_count is not null and agreed_payment_count > 0))
  ),
  constraint agreement_active_parties check (status <> 'ACTIVE' or (customer_id is not null and vehicle_id is not null))
);

create unique index agreements_one_active_vehicle on public.agreements (vehicle_id) where status = 'ACTIVE';
create index agreements_customer_status on public.agreements (customer_id, status);
create index agreements_status_start on public.agreements (status, start_date);
create unique index agreements_external_contract_unique
  on public.agreements (external_contract_provider, external_contract_id)
  where external_contract_provider is not null and external_contract_id is not null;

create table public.payment_schedule_items (
  id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references public.agreements (id),
  sequence_number integer not null check (sequence_number > 0),
  due_date date not null,
  amount_due numeric(12,2) not null check (amount_due > 0),
  status text not null default 'UPCOMING' check (status in ('UPCOMING','DUE','PARTIALLY_PAID','PAID','OVERDUE','WAIVED')),
  amount_paid numeric(12,2) not null default 0 check (amount_paid >= 0 and amount_paid <= amount_due),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (agreement_id, sequence_number),
  unique (agreement_id, due_date),
  constraint schedule_paid_state check ((status = 'PAID' and paid_at is not null and amount_paid = amount_due) or status <> 'PAID')
);

create index payment_schedule_due_status on public.payment_schedule_items (due_date, status);

create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references public.agreements (id),
  transaction_type text not null check (transaction_type in ('RECEIPT','REVERSAL','ADJUSTMENT')),
  amount numeric(12,2) not null check (amount <> 0),
  received_at timestamptz not null,
  reference text,
  notes text,
  reverses_transaction_id uuid references public.payment_transactions (id),
  unallocated_amount numeric(12,2) not null default 0,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  constraint payment_type_amount check (
    (transaction_type = 'RECEIPT' and amount > 0 and unallocated_amount >= 0)
    or (transaction_type in ('REVERSAL','ADJUSTMENT') and amount < 0 and unallocated_amount <= 0)
  )
);

create unique index payment_one_reversal on public.payment_transactions (reverses_transaction_id)
  where transaction_type = 'REVERSAL';
create index payment_transactions_agreement_history on public.payment_transactions (agreement_id, received_at desc);

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_transaction_id uuid not null references public.payment_transactions (id),
  payment_schedule_item_id uuid not null references public.payment_schedule_items (id),
  amount numeric(12,2) not null check (amount <> 0),
  created_at timestamptz not null default now(),
  unique (payment_transaction_id, payment_schedule_item_id)
);

create index payment_allocations_schedule_item on public.payment_allocations (payment_schedule_item_id);

create trigger agreements_touch_updated_at before update on public.agreements
for each row execute function app_private.touch_updated_at();

create or replace function app_private.protect_active_agreement_assignment()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.assignment_status = 'ACTIVE' and new.assignment_status = 'RETURNED'
    and exists (select 1 from public.agreements a where a.vehicle_id = old.vehicle_id
      and a.customer_id = old.customer_id and a.status = 'ACTIVE') then
    raise exception 'active agreement must be suspended, completed, or cancelled before assignment closes';
  end if;
  return new;
end; $$;

create trigger vehicle_assignments_protect_active_agreement
before update of assignment_status on public.vehicle_assignments
for each row execute function app_private.protect_active_agreement_assignment();

create or replace function app_private.reject_financial_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'financial transaction history is immutable' using errcode = '42501';
end; $$;

create trigger payment_transactions_immutable before update or delete on public.payment_transactions
for each row execute function app_private.reject_financial_mutation();
create trigger payment_allocations_immutable before update or delete on public.payment_allocations
for each row execute function app_private.reject_financial_mutation();

alter table public.agreements enable row level security;
alter table public.payment_schedule_items enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.payment_allocations enable row level security;

create policy staff_read_agreements on public.agreements for select to authenticated using (app_private.is_staff());
create policy staff_read_schedule on public.payment_schedule_items for select to authenticated using (app_private.is_staff());
create policy staff_read_payment_transactions on public.payment_transactions for select to authenticated using (app_private.is_staff());
create policy staff_read_payment_allocations on public.payment_allocations for select to authenticated using (app_private.is_staff());

revoke all on public.agreements, public.payment_schedule_items, public.payment_transactions, public.payment_allocations from anon, authenticated;
grant select on public.agreements, public.payment_schedule_items, public.payment_transactions, public.payment_allocations to authenticated;

create or replace function app_private.schedule_status(p_due_date date, p_amount_due numeric, p_amount_paid numeric, p_waived boolean default false)
returns text language sql stable set search_path = '' as $$
  select case
    when p_waived then 'WAIVED'
    when p_amount_paid >= p_amount_due then 'PAID'
    when p_amount_paid > 0 then 'PARTIALLY_PAID'
    when p_due_date < current_date then 'OVERDUE'
    when p_due_date = current_date then 'DUE'
    else 'UPCOMING'
  end;
$$;

create or replace function app_private.refresh_schedule_item(p_item_id uuid, p_paid_at timestamptz default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_paid numeric; v_due numeric; v_date date; v_old_status text;
begin
  select amount_due, due_date, status into v_due, v_date, v_old_status
  from public.payment_schedule_items where id = p_item_id for update;
  select coalesce(sum(pa.amount), 0) into v_paid from public.payment_allocations pa
  where pa.payment_schedule_item_id = p_item_id;
  v_paid := greatest(0, least(v_due, v_paid));
  update public.payment_schedule_items
  set amount_paid = v_paid,
      status = app_private.schedule_status(v_date, v_due, v_paid, v_old_status = 'WAIVED'),
      paid_at = case when v_paid = v_due then coalesce(p_paid_at, paid_at, now()) else null end
  where id = p_item_id;
end; $$;

create or replace function public.create_agreement(
  p_customer_id uuid, p_vehicle_id uuid, p_agreement_type text, p_start_date date,
  p_end_date date, p_first_due_date date, p_weekly_amount numeric, p_deposit_amount numeric default 0,
  p_agreed_total_amount numeric default null, p_agreed_payment_count integer default null,
  p_external_contract_provider text default null, p_external_contract_id text default null
) returns public.agreements
language plpgsql security definer set search_path = '' as $$
declare v_agreement public.agreements;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if p_agreement_type not in ('WEEKLY_RENTAL','RENT_TO_OWN','SHORT_TERM') then raise exception 'invalid agreement type' using errcode = '22023'; end if;
  insert into public.agreements (customer_id, vehicle_id, agreement_type, start_date, end_date,
    first_due_date, weekly_amount, deposit_amount, agreed_total_amount, agreed_payment_count,
    external_contract_provider, external_contract_id, created_by)
  values (p_customer_id, p_vehicle_id, p_agreement_type, p_start_date, p_end_date,
    p_first_due_date, p_weekly_amount, coalesce(p_deposit_amount,0), p_agreed_total_amount,
    p_agreed_payment_count, nullif(btrim(p_external_contract_provider),''),
    nullif(btrim(p_external_contract_id),''), auth.uid()) returning * into v_agreement;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'AGREEMENT_CREATED', 'agreement', v_agreement.id,
    jsonb_build_object('agreement_type', v_agreement.agreement_type, 'customer_id', v_agreement.customer_id, 'vehicle_id', v_agreement.vehicle_id));
  return v_agreement;
end; $$;

create or replace function public.generate_payment_schedule(
  p_agreement_id uuid, p_through_date date default null
) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_agreement public.agreements; v_limit date; v_inserted integer; v_max_count integer;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  select * into v_agreement from public.agreements where id = p_agreement_id for update;
  if not found then raise exception 'agreement not found'; end if;
  if v_agreement.status in ('COMPLETED','CANCELLED') then raise exception 'closed agreement cannot generate schedule'; end if;
  if v_agreement.status not in ('ACTIVE','SUSPENDED') then raise exception 'agreement must be active or suspended'; end if;
  v_limit := coalesce(p_through_date, current_date + 182);
  if v_agreement.end_date is not null then v_limit := least(v_limit, v_agreement.end_date); end if;
  if v_agreement.agreement_type = 'RENT_TO_OWN' and v_agreement.agreed_payment_count is not null then
    v_max_count := v_agreement.agreed_payment_count;
  else v_max_count := 10000; end if;
  insert into public.payment_schedule_items (agreement_id, sequence_number, due_date, amount_due, status)
  select v_agreement.id, s.n, v_agreement.first_due_date + ((s.n - 1) * 7),
    case when v_agreement.agreement_type = 'RENT_TO_OWN' and v_agreement.agreed_total_amount is not null
      then least(v_agreement.weekly_amount, greatest(0, v_agreement.agreed_total_amount - ((s.n - 1) * v_agreement.weekly_amount)))
      else v_agreement.weekly_amount end,
    app_private.schedule_status(v_agreement.first_due_date + ((s.n - 1) * 7),
      v_agreement.weekly_amount, 0)
  from generate_series(1, v_max_count) s(n)
  where v_agreement.first_due_date + ((s.n - 1) * 7) <= v_limit
    and (v_agreement.agreed_total_amount is null or ((s.n - 1) * v_agreement.weekly_amount) < v_agreement.agreed_total_amount)
  on conflict (agreement_id, sequence_number) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted > 0 then
    insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
    values (auth.uid(), 'SCHEDULE_GENERATED', 'agreement', v_agreement.id,
      jsonb_build_object('items_created', v_inserted, 'through_date', v_limit));
  end if;
  return v_inserted;
end; $$;

create or replace function public.transition_agreement(
  p_agreement_id uuid, p_new_status text, p_signed_at timestamptz default null
) returns public.agreements
language plpgsql security definer set search_path = '' as $$
declare v_before public.agreements; v_after public.agreements; v_action text;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  select * into v_before from public.agreements where id = p_agreement_id for update;
  if not found then raise exception 'agreement not found'; end if;
  if not ((v_before.status = 'DRAFT' and p_new_status in ('PENDING_SIGNATURE','CANCELLED'))
    or (v_before.status = 'PENDING_SIGNATURE' and p_new_status in ('ACTIVE','CANCELLED'))
    or (v_before.status = 'ACTIVE' and p_new_status in ('SUSPENDED','COMPLETED','CANCELLED'))
    or (v_before.status = 'SUSPENDED' and p_new_status in ('ACTIVE','COMPLETED','CANCELLED'))) then
    raise exception 'invalid agreement status transition';
  end if;
  if p_new_status = 'ACTIVE' then
    if v_before.customer_id is null or v_before.vehicle_id is null then raise exception 'active agreement requires customer and vehicle'; end if;
    if not exists (select 1 from public.vehicle_assignments va where va.customer_id = v_before.customer_id
      and va.vehicle_id = v_before.vehicle_id and va.assignment_status = 'ACTIVE' and va.returned_at is null) then
      raise exception 'active vehicle assignment required';
    end if;
    if exists (select 1 from public.agreements a where a.vehicle_id = v_before.vehicle_id and a.status = 'ACTIVE' and a.id <> v_before.id) then
      raise exception 'vehicle already has an active agreement';
    end if;
  end if;
  update public.agreements set status = p_new_status,
    signed_at = case when p_new_status = 'ACTIVE' then coalesce(p_signed_at, signed_at, now()) else signed_at end
  where id = p_agreement_id returning * into v_after;
  v_action := case p_new_status when 'ACTIVE' then 'AGREEMENT_ACTIVATED' when 'SUSPENDED' then 'AGREEMENT_SUSPENDED'
    when 'COMPLETED' then 'AGREEMENT_COMPLETED' when 'CANCELLED' then 'AGREEMENT_CANCELLED' else null end;
  if v_action is not null then insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
    values (auth.uid(), v_action, 'agreement', v_after.id, jsonb_build_object('from', v_before.status, 'to', p_new_status)); end if;
  if p_new_status = 'ACTIVE' then perform public.generate_payment_schedule(p_agreement_id, null); end if;
  return v_after;
end; $$;

create or replace function public.record_manual_payment(
  p_agreement_id uuid, p_amount numeric, p_received_at timestamptz,
  p_reference text default null, p_notes text default null
) returns public.payment_transactions
language plpgsql security definer set search_path = '' as $$
declare v_payment public.payment_transactions; v_remaining numeric; v_item record; v_allocate numeric;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'payment amount must be positive' using errcode = '22023'; end if;
  if p_received_at is null or p_received_at > now() then raise exception 'invalid received time' using errcode = '22023'; end if;
  if not exists (select 1 from public.agreements where id = p_agreement_id) then raise exception 'agreement not found'; end if;
  insert into public.payment_transactions (agreement_id, transaction_type, amount, received_at, reference, notes, created_by)
  values (p_agreement_id, 'RECEIPT', p_amount, p_received_at, nullif(btrim(p_reference),''),
    nullif(btrim(p_notes),''), auth.uid()) returning * into v_payment;
  v_remaining := p_amount;
  for v_item in select psi.id, psi.amount_due - psi.amount_paid as outstanding
    from public.payment_schedule_items psi where psi.agreement_id = p_agreement_id
      and psi.status <> 'WAIVED' and psi.amount_paid < psi.amount_due
    order by psi.due_date, psi.sequence_number for update
  loop
    exit when v_remaining <= 0;
    v_allocate := least(v_remaining, v_item.outstanding);
    insert into public.payment_allocations (payment_transaction_id, payment_schedule_item_id, amount)
    values (v_payment.id, v_item.id, v_allocate);
    perform app_private.refresh_schedule_item(v_item.id, p_received_at);
    v_remaining := v_remaining - v_allocate;
  end loop;
  if v_remaining > 0 then
    -- Insert-time completion of the immutable transaction row.
    update public.payment_transactions set unallocated_amount = v_remaining where id = v_payment.id;
  end if;
  select * into v_payment from public.payment_transactions where id = v_payment.id;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'PAYMENT_MANUALLY_RECORDED', 'payment_transaction', v_payment.id,
    jsonb_build_object('agreement_id', p_agreement_id, 'amount', p_amount, 'unallocated_amount', v_remaining));
  return v_payment;
end; $$;

-- The immutable trigger also blocks a function's insert-time update, so permit only that
-- specific initialization while keeping every existing transaction immutable.
create or replace function app_private.reject_financial_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and old.transaction_type = 'RECEIPT' and old.unallocated_amount = 0
    and new.unallocated_amount >= 0 and new.id = old.id and new.agreement_id = old.agreement_id
    and new.transaction_type = old.transaction_type and new.amount = old.amount
    and new.received_at = old.received_at and new.reference is not distinct from old.reference
    and new.notes is not distinct from old.notes and new.reverses_transaction_id is not distinct from old.reverses_transaction_id
    and new.created_by = old.created_by and new.created_at = old.created_at then return new; end if;
  raise exception 'financial transaction history is immutable' using errcode = '42501';
end; $$;

create or replace function public.reverse_manual_payment(
  p_payment_transaction_id uuid, p_reason text
) returns public.payment_transactions
language plpgsql security definer set search_path = '' as $$
declare v_original public.payment_transactions; v_reversal public.payment_transactions; v_allocation record;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if btrim(coalesce(p_reason,'')) = '' then raise exception 'reversal reason is required' using errcode = '22023'; end if;
  select * into v_original from public.payment_transactions where id = p_payment_transaction_id for update;
  if not found or v_original.transaction_type <> 'RECEIPT' then raise exception 'original receipt not found'; end if;
  if exists (select 1 from public.payment_transactions where reverses_transaction_id = v_original.id and transaction_type = 'REVERSAL') then
    raise exception 'payment already reversed';
  end if;
  insert into public.payment_transactions (agreement_id, transaction_type, amount, received_at, notes,
    reverses_transaction_id, unallocated_amount, created_by)
  values (v_original.agreement_id, 'REVERSAL', -v_original.amount, now(), btrim(p_reason),
    v_original.id, -v_original.unallocated_amount, auth.uid()) returning * into v_reversal;
  for v_allocation in select payment_schedule_item_id, amount from public.payment_allocations
    where payment_transaction_id = v_original.id order by created_at
  loop
    insert into public.payment_allocations (payment_transaction_id, payment_schedule_item_id, amount)
    values (v_reversal.id, v_allocation.payment_schedule_item_id, -v_allocation.amount);
    perform app_private.refresh_schedule_item(v_allocation.payment_schedule_item_id, null);
  end loop;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'PAYMENT_REVERSED', 'payment_transaction', v_reversal.id,
    jsonb_build_object('original_transaction_id', v_original.id, 'agreement_id', v_original.agreement_id, 'amount', v_original.amount));
  return v_reversal;
end; $$;

create or replace view public.agreement_payment_summary with (security_invoker = true) as
select a.id as agreement_id, a.customer_id, a.vehicle_id, a.weekly_amount,
  min(psi.due_date) filter (where psi.due_date < current_date and psi.status <> 'WAIVED' and psi.amount_paid < psi.amount_due) as oldest_overdue_date,
  count(*) filter (where psi.due_date < current_date and psi.status <> 'WAIVED' and psi.amount_paid < psi.amount_due)::integer as overdue_obligations,
  coalesce(sum(psi.amount_due - psi.amount_paid) filter (where psi.due_date < current_date and psi.status <> 'WAIVED'),0)::numeric(12,2) as overdue_amount,
  min(psi.due_date) filter (where psi.due_date >= current_date and psi.status <> 'WAIVED' and psi.amount_paid < psi.amount_due) as next_payment_date
from public.agreements a left join public.payment_schedule_items psi on psi.agreement_id = a.id
group by a.id;

create or replace view public.rent_to_own_progress with (security_invoker = true) as
select a.id as agreement_id, a.agreed_total_amount, a.agreed_payment_count,
  count(*) filter (where psi.amount_paid = psi.amount_due)::integer as payments_completed,
  greatest(0, coalesce(a.agreed_total_amount, sum(psi.amount_due)) - coalesce(sum(psi.amount_paid),0))::numeric(12,2) as scheduled_balance_remaining
from public.agreements a left join public.payment_schedule_items psi on psi.agreement_id = a.id
where a.agreement_type = 'RENT_TO_OWN' group by a.id;

create or replace function public.owner_payment_exceptions(
  p_overdue_days integer default 14, p_large_balance numeric default 2000
) returns table (exception_type text, agreement_id uuid, customer_id uuid, vehicle_id uuid, amount numeric, detail text)
language sql stable security definer set search_path = '' as $$
  select * from (
    select 'OVERDUE_DAYS', s.agreement_id, s.customer_id, s.vehicle_id, s.overdue_amount,
      'Oldest overdue: ' || s.oldest_overdue_date::text from public.agreement_payment_summary s
      where s.oldest_overdue_date < current_date - greatest(p_overdue_days,0)
    union all
    select 'LARGE_BALANCE', s.agreement_id, s.customer_id, s.vehicle_id, s.overdue_amount,
      'Overdue balance exceeds threshold' from public.agreement_payment_summary s where s.overdue_amount >= greatest(p_large_balance,0)
    union all
    select 'AWAITING_SIGNATURE', a.id, a.customer_id, a.vehicle_id, 0::numeric,
      'Agreement is pending signature' from public.agreements a where a.status = 'PENDING_SIGNATURE'
    union all
    select 'UNALLOCATED_PAYMENT', p.agreement_id, a.customer_id, a.vehicle_id, p.unallocated_amount,
      'Payment has unallocated funds' from public.payment_transactions p join public.agreements a on a.id = p.agreement_id
      where p.unallocated_amount > 0 and not exists (select 1 from public.payment_transactions r where r.reverses_transaction_id = p.id)
  ) exceptions where app_private.is_staff();
$$;

grant select on public.agreement_payment_summary, public.rent_to_own_progress to authenticated;
revoke all on function public.create_agreement(uuid,uuid,text,date,date,date,numeric,numeric,numeric,integer,text,text) from public;
revoke all on function public.generate_payment_schedule(uuid,date) from public;
revoke all on function public.transition_agreement(uuid,text,timestamptz) from public;
revoke all on function public.record_manual_payment(uuid,numeric,timestamptz,text,text) from public;
revoke all on function public.reverse_manual_payment(uuid,text) from public;
revoke all on function public.owner_payment_exceptions(integer,numeric) from public;
grant execute on function public.create_agreement(uuid,uuid,text,date,date,date,numeric,numeric,numeric,integer,text,text) to authenticated;
grant execute on function public.generate_payment_schedule(uuid,date) to authenticated;
grant execute on function public.transition_agreement(uuid,text,timestamptz) to authenticated;
grant execute on function public.record_manual_payment(uuid,numeric,timestamptz,text,text) to authenticated;
grant execute on function public.reverse_manual_payment(uuid,text) to authenticated;
grant execute on function public.owner_payment_exceptions(integer,numeric) to authenticated;

comment on table public.payment_transactions is 'Immutable manual receipt and compensating transaction ledger; no bank details.';
comment on table public.payment_allocations is 'Immutable allocation ledger. Positive receipts and negative reversal allocations preserve history.';
comment on function public.record_manual_payment(uuid,numeric,timestamptz,text,text) is
  'Allocates deterministically by earliest due date then sequence, including future obligations; remainder is retained as unallocated_amount.';
