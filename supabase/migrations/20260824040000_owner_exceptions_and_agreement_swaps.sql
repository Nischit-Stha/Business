-- Agreement-aware swaps, automated open-ended schedule extension, and owner exceptions.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED', 'VEHICLE_RETURNED', 'VEHICLE_SWAPPED', 'VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED', 'CUSTOMER_EDITED', 'CUSTOMER_STATUS_CHANGED',
  'VEHICLE_CREATED', 'VEHICLE_EDITED', 'STAFF_ACCESS_CHANGED',
  'AGREEMENT_CREATED', 'AGREEMENT_ACTIVATED', 'AGREEMENT_SUSPENDED',
  'AGREEMENT_COMPLETED', 'AGREEMENT_CANCELLED', 'PAYMENT_MANUALLY_RECORDED',
  'PAYMENT_REVERSED', 'PAYMENT_ADJUSTED', 'SCHEDULE_GENERATED',
  'AGREEMENT_VEHICLE_SWAPPED', 'SCHEDULE_EXTENSION_EXECUTED', 'SCHEDULE_EXTENSION_FAILED',
  'EXCEPTION_CREATED', 'EXCEPTION_ASSIGNED', 'EXCEPTION_RESOLVED'
));

create table public.operational_exceptions (
  id uuid primary key default gen_random_uuid(),
  exception_type text not null check (exception_type in (
    'OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','AGREEMENT_AWAITING_SIGNATURE',
    'UNALLOCATED_FUNDS','PAYMENT_ALLOCATION','SCHEDULE_EXTENSION_FAILURE',
    'VEHICLE_SWAP_FAILURE','VEHICLE_STATE_INCONSISTENCY','CUSTOMER_APPROVAL',
    'PICKUP_PREREQUISITE','RETURN_PREREQUISITE'
  )),
  severity text not null check (severity in ('LOW','MEDIUM','HIGH','CRITICAL')),
  entity_type text not null,
  entity_id uuid not null,
  dedup_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status text not null default 'OPEN' check (status in ('OPEN','ASSIGNED','RESOLVED')),
  assigned_to uuid references public.staff_profiles (user_id),
  resolved_at timestamptz,
  resolution_note text,
  summary text not null check (btrim(summary) <> '' and length(summary) <= 500),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  owner_only boolean not null default false,
  constraint exception_resolution_consistent check (
    (status = 'RESOLVED' and resolved_at is not null and btrim(coalesce(resolution_note,'')) <> '')
    or (status <> 'RESOLVED' and resolved_at is null)
  )
);

create unique index operational_exceptions_one_open_key
  on public.operational_exceptions (dedup_key) where status <> 'RESOLVED';
create index operational_exceptions_attention_order
  on public.operational_exceptions (status, severity, created_at);
create trigger operational_exceptions_touch_updated_at before update on public.operational_exceptions
for each row execute function app_private.touch_updated_at();

alter table public.operational_exceptions enable row level security;
create policy admins_read_staff_profiles on public.staff_profiles for select to authenticated
using (app_private.is_admin());
create policy staff_read_visible_exceptions on public.operational_exceptions for select to authenticated
using (app_private.is_staff() and (not owner_only or app_private.is_admin()));
revoke all on public.operational_exceptions from anon, authenticated;
grant select on public.operational_exceptions to authenticated;

create or replace function app_private.upsert_exception(
  p_type text, p_severity text, p_entity_type text, p_entity_id uuid, p_dedup_key text,
  p_summary text, p_metadata jsonb default '{}'::jsonb, p_owner_only boolean default false,
  p_actor uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_actor uuid; v_inserted boolean;
begin
  insert into public.operational_exceptions
    (exception_type,severity,entity_type,entity_id,dedup_key,summary,metadata,owner_only)
  values (p_type,p_severity,p_entity_type,p_entity_id,p_dedup_key,btrim(p_summary),coalesce(p_metadata,'{}'::jsonb),p_owner_only)
  on conflict (dedup_key) where status <> 'RESOLVED' do update
    set severity=excluded.severity, summary=excluded.summary, metadata=excluded.metadata,
        owner_only=excluded.owner_only, updated_at=now()
  returning id,(xmax=0) into v_id,v_inserted;
  if v_inserted then
    v_actor := coalesce(p_actor, auth.uid());
    if v_actor is not null then
      insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
      values(v_actor,'EXCEPTION_CREATED','operational_exception',v_id,
        jsonb_build_object('exception_type',p_type,'entity_type',p_entity_type,'entity_id',p_entity_id));
    end if;
  end if;
  return v_id;
end; $$;

create or replace function public.assign_exception(p_exception_id uuid, p_assigned_to uuid)
returns public.operational_exceptions language plpgsql security definer set search_path = '' as $$
declare v_result public.operational_exceptions;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if not exists(select 1 from public.staff_profiles where user_id=p_assigned_to and status='ACTIVE' and is_active) then
    raise exception 'active assignee not found';
  end if;
  update public.operational_exceptions set assigned_to=p_assigned_to,status='ASSIGNED'
  where id=p_exception_id and status <> 'RESOLVED'
    and (not owner_only or app_private.is_admin()) returning * into v_result;
  if not found then raise exception 'visible open exception not found'; end if;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
  values(auth.uid(),'EXCEPTION_ASSIGNED','operational_exception',p_exception_id,jsonb_build_object('assigned_to',p_assigned_to));
  return v_result;
end; $$;

create or replace function public.resolve_exception(p_exception_id uuid, p_resolution_note text)
returns public.operational_exceptions language plpgsql security definer set search_path = '' as $$
declare v_result public.operational_exceptions;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if btrim(coalesce(p_resolution_note,''))='' or length(btrim(p_resolution_note)) > 500 then
    raise exception 'resolution note is required and must be at most 500 characters' using errcode='22023';
  end if;
  update public.operational_exceptions set status='RESOLVED',resolved_at=now(),resolution_note=btrim(p_resolution_note)
  where id=p_exception_id and status <> 'RESOLVED'
    and (not owner_only or app_private.is_admin()) returning * into v_result;
  if not found then raise exception 'visible open exception not found'; end if;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
  values(auth.uid(),'EXCEPTION_RESOLVED','operational_exception',p_exception_id,jsonb_build_object('resolution_note',btrim(p_resolution_note)));
  return v_result;
end; $$;

create or replace function public.report_vehicle_swap_failure(p_agreement_id uuid, p_summary text, p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  if not exists(select 1 from public.agreements where id=p_agreement_id) then raise exception 'agreement not found'; end if;
  v_id := app_private.upsert_exception('VEHICLE_SWAP_FAILURE','HIGH','agreement',p_agreement_id,
    'vehicle-swap:'||p_agreement_id::text,coalesce(nullif(btrim(p_summary),''),'Vehicle swap failed'),p_metadata,true,auth.uid());
  return v_id;
end; $$;

create or replace function public.swap_active_agreement_vehicle(
  p_agreement_id uuid, p_new_vehicle_id uuid, p_old_return_odometer integer,
  p_new_pickup_odometer integer, p_swapped_at timestamptz default now()
) returns public.vehicle_assignments language plpgsql security definer set search_path = '' as $$
declare v_agreement public.agreements; v_old public.vehicle_assignments;
  v_old_vehicle public.vehicles; v_new_vehicle public.vehicles; v_new public.vehicle_assignments;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  select * into v_agreement from public.agreements where id=p_agreement_id for update;
  if not found or v_agreement.status <> 'ACTIVE' then raise exception 'active agreement not found'; end if;
  if v_agreement.vehicle_id=p_new_vehicle_id then raise exception 'replacement vehicle must be different'; end if;
  select * into v_old from public.vehicle_assignments
    where vehicle_id=v_agreement.vehicle_id and customer_id=v_agreement.customer_id
      and assignment_status='ACTIVE' and returned_at is null for update;
  if not found then raise exception 'agreement assignment state is inconsistent'; end if;
  perform 1 from public.vehicles where id in (v_agreement.vehicle_id,p_new_vehicle_id) order by id for update;
  select * into v_old_vehicle from public.vehicles where id=v_agreement.vehicle_id;
  select * into v_new_vehicle from public.vehicles where id=p_new_vehicle_id;
  if not found then raise exception 'replacement vehicle not found'; end if;
  if v_old_vehicle.operational_status <> 'ASSIGNED' then raise exception 'agreement vehicle state is inconsistent'; end if;
  if v_new_vehicle.operational_status <> 'AVAILABLE'
    or exists(select 1 from public.vehicle_assignments where vehicle_id=p_new_vehicle_id and returned_at is null)
    or exists(select 1 from public.agreements where vehicle_id=p_new_vehicle_id and status='ACTIVE') then
    raise exception 'replacement vehicle is not available';
  end if;
  if p_swapped_at < v_old.assigned_at or p_swapped_at > now() then raise exception 'invalid swap time'; end if;
  if p_old_return_odometer is null or p_new_pickup_odometer is null
    or p_old_return_odometer < greatest(v_old.pickup_odometer,v_old_vehicle.odometer)
    or p_new_pickup_odometer < v_new_vehicle.odometer then raise exception 'odometer cannot move backwards'; end if;

  -- Temporarily move the agreement reference so the active-assignment guard permits the close.
  update public.agreements set vehicle_id=p_new_vehicle_id where id=p_agreement_id;
  update public.vehicle_assignments set returned_at=p_swapped_at,return_odometer=p_old_return_odometer,
    assignment_status='RETURNED' where id=v_old.id;
  update public.vehicles set operational_status='AVAILABLE',odometer=p_old_return_odometer where id=v_old.vehicle_id;
  insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by)
  values(v_agreement.customer_id,p_new_vehicle_id,p_swapped_at,p_new_pickup_odometer,'ACTIVE',auth.uid()) returning * into v_new;
  update public.vehicles set operational_status='ASSIGNED',odometer=p_new_pickup_odometer where id=p_new_vehicle_id;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
  values(auth.uid(),'AGREEMENT_VEHICLE_SWAPPED','agreement',p_agreement_id,
    jsonb_build_object('customer_id',v_agreement.customer_id,'previous_assignment_id',v_old.id,
      'new_assignment_id',v_new.id,'from_vehicle_id',v_old.vehicle_id,'to_vehicle_id',p_new_vehicle_id,
      'old_return_odometer',p_old_return_odometer,'new_pickup_odometer',p_new_pickup_odometer));
  return v_new;
end; $$;

create or replace function app_private.extend_open_agreement_schedules(p_future_weeks integer default 12, p_actor uuid default null)
returns table(agreements_checked integer, agreements_extended integer, items_created integer, failures integer)
language plpgsql security definer set search_path = '' as $$
declare v_agreement record; v_created integer; v_checked integer:=0; v_extended integer:=0; v_items integer:=0; v_failures integer:=0;
begin
  if p_future_weeks not between 8 and 12 then raise exception 'future weeks must be between 8 and 12' using errcode='22023'; end if;
  for v_agreement in select id from public.agreements where status='ACTIVE' and end_date is null order by id loop
    v_checked:=v_checked+1;
    begin
      -- Run as the supplied staff actor when manually invoked; scheduled postgres runs bypass the public wrapper.
      v_created:=public.generate_payment_schedule(v_agreement.id,current_date+(p_future_weeks*7));
      if v_created>0 then v_extended:=v_extended+1; v_items:=v_items+v_created; end if;
      if p_actor is not null then
        insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
        values(p_actor,'SCHEDULE_EXTENSION_EXECUTED','agreement',v_agreement.id,
          jsonb_build_object('items_created',v_created,'future_weeks',p_future_weeks));
      end if;
    exception when others then
      v_failures:=v_failures+1;
      perform app_private.upsert_exception('SCHEDULE_EXTENSION_FAILURE','HIGH','agreement',v_agreement.id,
        'schedule-extension:'||v_agreement.id::text,'Automatic schedule extension failed',
        jsonb_build_object('sqlstate',sqlstate,'error',sqlerrm,'future_weeks',p_future_weeks),true,p_actor);
      if p_actor is not null then insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
        values(p_actor,'SCHEDULE_EXTENSION_FAILED','agreement',v_agreement.id,jsonb_build_object('sqlstate',sqlstate,'error',sqlerrm)); end if;
    end;
  end loop;
  return query select v_checked,v_extended,v_items,v_failures;
end; $$;

create or replace function public.run_open_agreement_schedule_extension(p_future_weeks integer default 12)
returns table(agreements_checked integer, agreements_extended integer, items_created integer, failures integer)
language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501'; end if;
  return query select * from app_private.extend_open_agreement_schedules(p_future_weeks,auth.uid());
end; $$;

create or replace function public.refresh_owner_exceptions(p_overdue_days integer default 14,p_large_balance numeric default 2000)
returns integer language plpgsql security definer set search_path = '' as $$
declare v record; v_count integer:=0;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  for v in select * from public.owner_payment_exceptions(p_overdue_days,p_large_balance) loop
    perform app_private.upsert_exception(
      case v.exception_type when 'OVERDUE_DAYS' then 'OVERDUE_CUSTOMER' when 'LARGE_BALANCE' then 'HIGH_OUTSTANDING_BALANCE'
        when 'AWAITING_SIGNATURE' then 'AGREEMENT_AWAITING_SIGNATURE' else 'UNALLOCATED_FUNDS' end,
      case when v.exception_type='LARGE_BALANCE' then 'HIGH' when v.exception_type='OVERDUE_DAYS' then 'HIGH' else 'MEDIUM' end,
      'agreement',v.agreement_id,lower(v.exception_type)||':'||v.agreement_id::text,
      v.detail,jsonb_build_object('amount',v.amount,'customer_id',v.customer_id,'vehicle_id',v.vehicle_id),
      v.exception_type in ('LARGE_BALANCE','OVERDUE_DAYS'),auth.uid());
    v_count:=v_count+1;
  end loop;
  for v in select a.id from public.agreements a where a.status='ACTIVE' and (
    not exists(select 1 from public.vehicle_assignments va where va.vehicle_id=a.vehicle_id and va.customer_id=a.customer_id and va.assignment_status='ACTIVE')
    or not exists(select 1 from public.vehicles ve where ve.id=a.vehicle_id and ve.operational_status='ASSIGNED')) loop
    perform app_private.upsert_exception('VEHICLE_STATE_INCONSISTENCY','CRITICAL','agreement',v.id,
      'vehicle-state:'||v.id::text,'Active agreement has inconsistent vehicle or assignment state','{}'::jsonb,true,auth.uid());
    v_count:=v_count+1;
  end loop;
  return v_count;
end; $$;

create or replace function public.owner_dashboard_metrics(p_overdue_days integer default 14)
returns table(active_vehicles bigint,available_vehicles bigint,active_agreements bigint,overdue_amount numeric,overdue_customers bigint,attention_items bigint)
language sql stable security definer set search_path = '' as $$
  select
    (select count(*) from public.vehicles where operational_status='ASSIGNED'),
    (select count(*) from public.vehicles where operational_status='AVAILABLE'),
    (select count(*) from public.agreements where status='ACTIVE'),
    (select coalesce(sum(s.overdue_amount),0) from public.agreement_payment_summary s join public.agreements a on a.id=s.agreement_id where a.status='ACTIVE'),
    (select count(distinct a.customer_id) from public.agreement_payment_summary s join public.agreements a on a.id=s.agreement_id
      where a.status='ACTIVE' and s.oldest_overdue_date < current_date-greatest(p_overdue_days,0)),
    (select count(*) from public.operational_exceptions e where e.status<>'RESOLVED' and (not e.owner_only or app_private.is_admin()))
  where app_private.is_staff();
$$;

revoke all on function public.swap_active_agreement_vehicle(uuid,uuid,integer,integer,timestamptz) from public;
revoke all on function public.assign_exception(uuid,uuid) from public;
revoke all on function public.resolve_exception(uuid,text) from public;
revoke all on function public.report_vehicle_swap_failure(uuid,text,jsonb) from public;
revoke all on function public.run_open_agreement_schedule_extension(integer) from public;
revoke all on function public.refresh_owner_exceptions(integer,numeric) from public;
revoke all on function public.owner_dashboard_metrics(integer) from public;
grant execute on function public.swap_active_agreement_vehicle(uuid,uuid,integer,integer,timestamptz) to authenticated;
grant execute on function public.assign_exception(uuid,uuid) to authenticated;
grant execute on function public.resolve_exception(uuid,text) to authenticated;
grant execute on function public.report_vehicle_swap_failure(uuid,text,jsonb) to authenticated;
grant execute on function public.run_open_agreement_schedule_extension(integer) to authenticated;
grant execute on function public.refresh_owner_exceptions(integer,numeric) to authenticated;
grant execute on function public.owner_dashboard_metrics(integer) to authenticated;

comment on function public.run_open_agreement_schedule_extension(integer) is
  'Authenticated admin scheduler target for local/staging. Invoke daily with a dedicated active admin JWT; do not configure production without review.';
