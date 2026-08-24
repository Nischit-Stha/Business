create extension if not exists btree_gist with schema extensions;

create table public.staff_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null check (btrim(full_name) <> ''),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (btrim(full_name) <> ''),
  phone text,
  email text,
  address text,
  licence_number text not null,
  licence_expiry date,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'INACTIVE', 'BLOCKED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index customers_licence_number_unique
  on public.customers (upper(licence_number));

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  registration text not null,
  vin text,
  make text not null,
  model text not null,
  year integer not null check (year between 1900 and 2100),
  odometer integer not null default 0 check (odometer >= 0),
  operational_status text not null default 'AVAILABLE'
    check (operational_status in ('AVAILABLE', 'ASSIGNED', 'PICKUP_PENDING', 'RETURN_PENDING', 'WORKSHOP', 'OFF_ROAD')),
  weekly_rate numeric(10, 2) not null check (weekly_rate >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index vehicles_registration_unique on public.vehicles (upper(registration));
create unique index vehicles_vin_unique on public.vehicles (upper(vin)) where vin is not null;

create table public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers (id),
  vehicle_id uuid not null references public.vehicles (id),
  assigned_at timestamptz not null default now(),
  returned_at timestamptz,
  pickup_odometer integer not null check (pickup_odometer >= 0),
  return_odometer integer,
  assignment_status text not null default 'ACTIVE' check (assignment_status in ('ACTIVE', 'RETURNED')),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  constraint assignment_return_state_consistent check (
    (assignment_status = 'ACTIVE' and returned_at is null and return_odometer is null)
    or
    (assignment_status = 'RETURNED' and returned_at is not null and return_odometer is not null)
  ),
  constraint assignment_time_order check (returned_at is null or returned_at > assigned_at),
  constraint assignment_odometer_order check (return_odometer is null or return_odometer >= pickup_odometer),
  constraint vehicle_assignments_no_overlap exclude using gist (
    vehicle_id with =,
    tstzrange(assigned_at, returned_at, '[)') with &&
  )
);

create unique index vehicle_assignments_one_active_vehicle
  on public.vehicle_assignments (vehicle_id) where returned_at is null;
create index vehicle_assignments_customer_history
  on public.vehicle_assignments (customer_id, assigned_at desc);
create index vehicle_assignments_vehicle_history
  on public.vehicle_assignments (vehicle_id, assigned_at desc);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor uuid not null references auth.users (id),
  occurred_at timestamptz not null default now(),
  action text not null check (action in ('ASSIGNMENT_CREATED', 'VEHICLE_RETURNED', 'VEHICLE_SWAPPED', 'VEHICLE_STATUS_CHANGED')),
  entity_type text not null,
  entity_id uuid not null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object')
);

create index audit_events_entity_history
  on public.audit_events (entity_type, entity_id, occurred_at desc);

create or replace function app_private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_profiles
    where user_id = auth.uid() and is_active
  );
$$;

revoke all on function app_private.is_staff() from public;
grant execute on function app_private.is_staff() to authenticated;

create or replace function app_private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger staff_profiles_touch_updated_at before update on public.staff_profiles
for each row execute function app_private.touch_updated_at();
create trigger customers_touch_updated_at before update on public.customers
for each row execute function app_private.touch_updated_at();
create trigger vehicles_touch_updated_at before update on public.vehicles
for each row execute function app_private.touch_updated_at();

create or replace function app_private.audit_vehicle_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.operational_status is distinct from new.operational_status then
    insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
    values (
      auth.uid(),
      'VEHICLE_STATUS_CHANGED',
      'vehicle',
      new.id,
      jsonb_build_object('from', old.operational_status, 'to', new.operational_status)
    );
  end if;
  return new;
end;
$$;

create trigger vehicles_audit_status_change after update of operational_status on public.vehicles
for each row execute function app_private.audit_vehicle_status_change();

alter table public.staff_profiles enable row level security;
alter table public.customers enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_assignments enable row level security;
alter table public.audit_events enable row level security;

create policy staff_read_own_profile on public.staff_profiles for select to authenticated
using (user_id = auth.uid() and app_private.is_staff());
create policy staff_read_customers on public.customers for select to authenticated
using (app_private.is_staff());
create policy staff_read_vehicles on public.vehicles for select to authenticated
using (app_private.is_staff());
create policy staff_read_assignments on public.vehicle_assignments for select to authenticated
using (app_private.is_staff());
create policy staff_read_audit on public.audit_events for select to authenticated
using (app_private.is_staff());

revoke all on public.staff_profiles, public.customers, public.vehicles,
  public.vehicle_assignments, public.audit_events from anon, authenticated;
grant select on public.staff_profiles, public.customers, public.vehicles,
  public.vehicle_assignments, public.audit_events to authenticated;

create or replace function public.assign_vehicle_to_customer(
  p_customer_id uuid,
  p_vehicle_id uuid,
  p_pickup_odometer integer,
  p_assigned_at timestamptz default now()
)
returns public.vehicle_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vehicle public.vehicles;
  v_assignment public.vehicle_assignments;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if p_assigned_at > now() then raise exception 'assigned_at cannot be in the future'; end if;
  if p_pickup_odometer is null or p_pickup_odometer < 0 then raise exception 'invalid pickup odometer'; end if;
  if not exists (select 1 from public.customers where id = p_customer_id and status = 'ACTIVE') then
    raise exception 'active customer not found';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id for update;
  if not found then raise exception 'vehicle not found'; end if;
  if v_vehicle.operational_status not in ('AVAILABLE', 'PICKUP_PENDING') then raise exception 'vehicle is not available'; end if;
  if p_pickup_odometer < v_vehicle.odometer then raise exception 'odometer cannot move backwards'; end if;

  insert into public.vehicle_assignments
    (customer_id, vehicle_id, assigned_at, pickup_odometer, assignment_status, created_by)
  values (p_customer_id, p_vehicle_id, p_assigned_at, p_pickup_odometer, 'ACTIVE', auth.uid())
  returning * into v_assignment;

  update public.vehicles set operational_status = 'ASSIGNED', odometer = p_pickup_odometer
  where id = p_vehicle_id;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'ASSIGNMENT_CREATED', 'vehicle_assignment', v_assignment.id,
    jsonb_build_object('customer_id', p_customer_id, 'vehicle_id', p_vehicle_id));
  return v_assignment;
end;
$$;

create or replace function public.return_vehicle(
  p_assignment_id uuid,
  p_return_odometer integer,
  p_returned_at timestamptz default now()
)
returns public.vehicle_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.vehicle_assignments;
  v_vehicle public.vehicles;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  select * into v_assignment from public.vehicle_assignments where id = p_assignment_id for update;
  if not found or v_assignment.assignment_status <> 'ACTIVE' then raise exception 'active assignment not found'; end if;
  select * into v_vehicle from public.vehicles where id = v_assignment.vehicle_id for update;
  if p_returned_at < v_assignment.assigned_at or p_returned_at > now() then raise exception 'invalid return time'; end if;
  if p_return_odometer is null or p_return_odometer < greatest(v_assignment.pickup_odometer, v_vehicle.odometer) then
    raise exception 'odometer cannot move backwards';
  end if;

  update public.vehicle_assignments set returned_at = p_returned_at,
    return_odometer = p_return_odometer, assignment_status = 'RETURNED'
  where id = p_assignment_id returning * into v_assignment;
  update public.vehicles set operational_status = 'AVAILABLE', odometer = p_return_odometer
  where id = v_assignment.vehicle_id;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'VEHICLE_RETURNED', 'vehicle_assignment', v_assignment.id,
    jsonb_build_object('vehicle_id', v_assignment.vehicle_id, 'return_odometer', p_return_odometer));
  return v_assignment;
end;
$$;

create or replace function public.swap_vehicle(
  p_assignment_id uuid,
  p_new_vehicle_id uuid,
  p_old_return_odometer integer,
  p_new_pickup_odometer integer,
  p_swapped_at timestamptz default now()
)
returns public.vehicle_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.vehicle_assignments;
  v_old_vehicle public.vehicles;
  v_new_vehicle public.vehicles;
  v_new public.vehicle_assignments;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  select * into v_old from public.vehicle_assignments where id = p_assignment_id for update;
  if not found or v_old.assignment_status <> 'ACTIVE' then raise exception 'active assignment not found'; end if;
  if v_old.vehicle_id = p_new_vehicle_id then raise exception 'replacement vehicle must be different'; end if;

  perform 1 from public.vehicles where id in (v_old.vehicle_id, p_new_vehicle_id) order by id for update;
  select * into v_old_vehicle from public.vehicles where id = v_old.vehicle_id;
  select * into v_new_vehicle from public.vehicles where id = p_new_vehicle_id;
  if not found then raise exception 'replacement vehicle not found'; end if;
  if v_new_vehicle.operational_status not in ('AVAILABLE', 'PICKUP_PENDING') then raise exception 'replacement vehicle is not available'; end if;
  if p_swapped_at < v_old.assigned_at or p_swapped_at > now() then raise exception 'invalid swap time'; end if;
  if p_old_return_odometer < greatest(v_old.pickup_odometer, v_old_vehicle.odometer)
    or p_new_pickup_odometer < v_new_vehicle.odometer then raise exception 'odometer cannot move backwards'; end if;

  update public.vehicle_assignments set returned_at = p_swapped_at,
    return_odometer = p_old_return_odometer, assignment_status = 'RETURNED'
  where id = v_old.id;
  update public.vehicles set operational_status = 'AVAILABLE', odometer = p_old_return_odometer where id = v_old.vehicle_id;
  insert into public.vehicle_assignments
    (customer_id, vehicle_id, assigned_at, pickup_odometer, assignment_status, created_by)
  values (v_old.customer_id, p_new_vehicle_id, p_swapped_at, p_new_pickup_odometer, 'ACTIVE', auth.uid())
  returning * into v_new;
  update public.vehicles set operational_status = 'ASSIGNED', odometer = p_new_pickup_odometer where id = p_new_vehicle_id;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'VEHICLE_SWAPPED', 'vehicle_assignment', v_new.id,
    jsonb_build_object('previous_assignment_id', v_old.id, 'from_vehicle_id', v_old.vehicle_id, 'to_vehicle_id', p_new_vehicle_id));
  return v_new;
end;
$$;

revoke all on function public.assign_vehicle_to_customer(uuid, uuid, integer, timestamptz) from public;
revoke all on function public.return_vehicle(uuid, integer, timestamptz) from public;
revoke all on function public.swap_vehicle(uuid, uuid, integer, integer, timestamptz) from public;
grant execute on function public.assign_vehicle_to_customer(uuid, uuid, integer, timestamptz) to authenticated;
grant execute on function public.return_vehicle(uuid, integer, timestamptz) to authenticated;
grant execute on function public.swap_vehicle(uuid, uuid, integer, integer, timestamptz) to authenticated;

comment on table public.customers is 'Normalized V2 customer records; licence files belong in private Storage.';
comment on table public.vehicle_assignments is 'Immutable vehicle custody history; active rows are closed by trusted workflows.';
