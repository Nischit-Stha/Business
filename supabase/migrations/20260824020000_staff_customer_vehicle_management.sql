alter table public.staff_profiles
  add column role text not null default 'STAFF'
    check (role in ('ADMIN', 'STAFF')),
  add column status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'DISABLED'));

update public.staff_profiles set status = case when is_active then 'ACTIVE' else 'DISABLED' end;

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED', 'VEHICLE_RETURNED', 'VEHICLE_SWAPPED', 'VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED', 'CUSTOMER_EDITED', 'CUSTOMER_STATUS_CHANGED',
  'VEHICLE_CREATED', 'VEHICLE_EDITED', 'STAFF_ACCESS_CHANGED'
));

create or replace function app_private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_profiles
    where user_id = auth.uid() and is_active and status = 'ACTIVE'
  );
$$;

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_profiles
    where user_id = auth.uid() and is_active and status = 'ACTIVE' and role = 'ADMIN'
  );
$$;

revoke all on function app_private.is_admin() from public;
grant execute on function app_private.is_admin() to authenticated;

create or replace function app_private.require_text(p_value text, p_label text, p_max integer)
returns text language plpgsql immutable set search_path = '' as $$
declare v_value text := btrim(coalesce(p_value, ''));
begin
  if v_value = '' then raise exception '% is required', p_label using errcode = '22023'; end if;
  if length(v_value) > p_max then raise exception '% is too long', p_label using errcode = '22023'; end if;
  return v_value;
end;
$$;

create or replace function app_private.valid_email(p_email text)
returns boolean language sql immutable set search_path = '' as $$
  select p_email ~* '^[A-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$';
$$;

create or replace function public.create_customer(
  p_full_name text, p_phone text, p_email text, p_licence_number text,
  p_licence_expiry date, p_address text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare v_customer public.customers;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if btrim(coalesce(p_phone, '')) !~ '^\+?[0-9 ()-]{8,20}$' then raise exception 'invalid phone' using errcode = '22023'; end if;
  if not app_private.valid_email(btrim(coalesce(p_email, ''))) then raise exception 'invalid email' using errcode = '22023'; end if;
  if p_licence_expiry is null then raise exception 'licence expiry is required' using errcode = '22023'; end if;
  insert into public.customers (full_name, phone, email, licence_number, licence_expiry, address)
  values (app_private.require_text(p_full_name, 'full name', 160), btrim(p_phone), lower(btrim(p_email)),
    upper(app_private.require_text(p_licence_number, 'licence number', 80)), p_licence_expiry,
    app_private.require_text(p_address, 'address', 500)) returning * into v_customer;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'CUSTOMER_CREATED', 'customer', v_customer.id, jsonb_build_object('after', to_jsonb(v_customer) - array['phone','email','address','licence_number']));
  return v_customer;
end; $$;

create or replace function public.update_customer(
  p_id uuid, p_full_name text, p_phone text, p_email text, p_licence_number text,
  p_licence_expiry date, p_address text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare v_before public.customers; v_customer public.customers;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if btrim(coalesce(p_phone, '')) !~ '^\+?[0-9 ()-]{8,20}$' then raise exception 'invalid phone' using errcode = '22023'; end if;
  if not app_private.valid_email(btrim(coalesce(p_email, ''))) then raise exception 'invalid email' using errcode = '22023'; end if;
  if p_licence_expiry is null then raise exception 'licence expiry is required' using errcode = '22023'; end if;
  select * into v_before from public.customers where id = p_id for update;
  if not found then raise exception 'customer not found'; end if;
  update public.customers set full_name = app_private.require_text(p_full_name, 'full name', 160),
    phone = btrim(p_phone), email = lower(btrim(p_email)),
    licence_number = upper(app_private.require_text(p_licence_number, 'licence number', 80)),
    licence_expiry = p_licence_expiry, address = app_private.require_text(p_address, 'address', 500)
  where id = p_id returning * into v_customer;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'CUSTOMER_EDITED', 'customer', p_id,
    jsonb_build_object('before', to_jsonb(v_before) - array['phone','email','address','licence_number'], 'after', to_jsonb(v_customer) - array['phone','email','address','licence_number']));
  return v_customer;
end; $$;

create or replace function public.change_customer_status(p_id uuid, p_status text)
returns public.customers language plpgsql security definer set search_path = '' as $$
declare v_before text; v_customer public.customers;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if p_status not in ('ACTIVE','INACTIVE','BLOCKED') then raise exception 'invalid customer status' using errcode = '22023'; end if;
  select status into v_before from public.customers where id = p_id for update;
  if not found then raise exception 'customer not found'; end if;
  update public.customers set status = p_status where id = p_id returning * into v_customer;
  if v_before is distinct from p_status then
    insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
    values (auth.uid(), 'CUSTOMER_STATUS_CHANGED', 'customer', p_id, jsonb_build_object('from', v_before, 'to', p_status));
  end if;
  return v_customer;
end; $$;

create or replace function public.create_vehicle(
  p_registration text, p_vin text, p_make text, p_model text, p_year integer,
  p_odometer integer, p_weekly_rate numeric, p_operational_status text default 'AVAILABLE'
) returns public.vehicles language plpgsql security definer set search_path = '' as $$
declare v_vehicle public.vehicles;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  if p_year not between 1900 and extract(year from current_date)::integer + 1 then raise exception 'invalid year' using errcode = '22023'; end if;
  if p_odometer is null or p_odometer < 0 then raise exception 'invalid odometer' using errcode = '22023'; end if;
  if p_weekly_rate is null or p_weekly_rate < 0 then raise exception 'invalid weekly rate' using errcode = '22023'; end if;
  if p_operational_status not in ('AVAILABLE','WORKSHOP','OFF_ROAD') then raise exception 'assignment state is workflow controlled' using errcode = '42501'; end if;
  insert into public.vehicles (registration, vin, make, model, year, odometer, weekly_rate, operational_status)
  values (upper(app_private.require_text(p_registration, 'registration', 20)), nullif(upper(btrim(coalesce(p_vin,''))), ''),
    app_private.require_text(p_make, 'make', 80), app_private.require_text(p_model, 'model', 80),
    p_year, p_odometer, p_weekly_rate, p_operational_status) returning * into v_vehicle;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'VEHICLE_CREATED', 'vehicle', v_vehicle.id, jsonb_build_object('registration', v_vehicle.registration));
  return v_vehicle;
end; $$;

create or replace function public.update_vehicle(
  p_id uuid, p_registration text, p_vin text, p_make text, p_model text, p_year integer,
  p_odometer integer, p_weekly_rate numeric, p_operational_status text
) returns public.vehicles language plpgsql security definer set search_path = '' as $$
declare v_before public.vehicles; v_vehicle public.vehicles;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode = '42501'; end if;
  select * into v_before from public.vehicles where id = p_id for update;
  if not found then raise exception 'vehicle not found'; end if;
  if p_year not between 1900 and extract(year from current_date)::integer + 1 then raise exception 'invalid year' using errcode = '22023'; end if;
  if p_odometer is null or p_odometer < v_before.odometer then raise exception 'odometer cannot move backwards' using errcode = '22023'; end if;
  if p_weekly_rate is null or p_weekly_rate < 0 then raise exception 'invalid weekly rate' using errcode = '22023'; end if;
  if v_before.operational_status in ('ASSIGNED','PICKUP_PENDING','RETURN_PENDING') and p_operational_status <> v_before.operational_status then
    raise exception 'assignment state is workflow controlled' using errcode = '42501';
  end if;
  if p_operational_status not in ('AVAILABLE','WORKSHOP','OFF_ROAD','ASSIGNED','PICKUP_PENDING','RETURN_PENDING') then raise exception 'invalid operational status' using errcode = '22023'; end if;
  if p_operational_status in ('ASSIGNED','PICKUP_PENDING','RETURN_PENDING') and p_operational_status <> v_before.operational_status then
    raise exception 'assignment state is workflow controlled' using errcode = '42501';
  end if;
  update public.vehicles set registration = upper(app_private.require_text(p_registration, 'registration', 20)),
    vin = nullif(upper(btrim(coalesce(p_vin,''))), ''), make = app_private.require_text(p_make, 'make', 80),
    model = app_private.require_text(p_model, 'model', 80), year = p_year, odometer = p_odometer,
    weekly_rate = p_weekly_rate, operational_status = p_operational_status
  where id = p_id returning * into v_vehicle;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'VEHICLE_EDITED', 'vehicle', p_id,
    jsonb_build_object('before', to_jsonb(v_before) - 'vin', 'after', to_jsonb(v_vehicle) - 'vin'));
  return v_vehicle;
end; $$;

create or replace function public.set_staff_access(p_user_id uuid, p_full_name text, p_role text, p_status text)
returns public.staff_profiles language plpgsql security definer set search_path = '' as $$
declare v_before public.staff_profiles; v_profile public.staff_profiles;
begin
  if not app_private.is_admin() then raise exception 'admin access required' using errcode = '42501'; end if;
  if p_role not in ('ADMIN','STAFF') or p_status not in ('ACTIVE','DISABLED') then raise exception 'invalid staff access values' using errcode = '22023'; end if;
  select * into v_before from public.staff_profiles where user_id = p_user_id for update;
  insert into public.staff_profiles (user_id, full_name, role, status, is_active)
  values (p_user_id, app_private.require_text(p_full_name, 'full name', 160), p_role, p_status, p_status = 'ACTIVE')
  on conflict (user_id) do update set full_name = excluded.full_name, role = excluded.role,
    status = excluded.status, is_active = excluded.is_active returning * into v_profile;
  insert into public.audit_events (actor, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'STAFF_ACCESS_CHANGED', 'staff_profile', p_user_id,
    jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_profile)));
  return v_profile;
end; $$;

revoke all on function public.create_customer(text,text,text,text,date,text) from public;
revoke all on function public.update_customer(uuid,text,text,text,text,date,text) from public;
revoke all on function public.change_customer_status(uuid,text) from public;
revoke all on function public.create_vehicle(text,text,text,text,integer,integer,numeric,text) from public;
revoke all on function public.update_vehicle(uuid,text,text,text,text,integer,integer,numeric,text) from public;
revoke all on function public.set_staff_access(uuid,text,text,text) from public;
grant execute on function public.create_customer(text,text,text,text,date,text) to authenticated;
grant execute on function public.update_customer(uuid,text,text,text,text,date,text) to authenticated;
grant execute on function public.change_customer_status(uuid,text) to authenticated;
grant execute on function public.create_vehicle(text,text,text,text,integer,integer,numeric,text) to authenticated;
grant execute on function public.update_vehicle(uuid,text,text,text,text,integer,integer,numeric,text) to authenticated;
grant execute on function public.set_staff_access(uuid,text,text,text) to authenticated;
