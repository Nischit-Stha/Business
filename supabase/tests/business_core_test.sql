begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('30000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@example.test', '', now(), now(), now()),
  ('30000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider@example.test', '', now(), now(), now());
insert into public.staff_profiles (user_id, full_name)
values ('30000000-0000-4000-8000-000000000001', 'Synthetic Staff');
insert into public.customers (id, full_name, licence_number, status)
values ('40000000-0000-4000-8000-000000000001', 'Test Customer', 'TEST-LICENCE-001', 'ACTIVE');
insert into public.vehicles (id, registration, make, model, year, odometer, operational_status, weekly_rate)
values
  ('50000000-0000-4000-8000-000000000001', 'TEST01', 'Test', 'One', 2024, 1000, 'AVAILABLE', 400),
  ('50000000-0000-4000-8000-000000000002', 'TEST02', 'Test', 'Two', 2024, 2000, 'AVAILABLE', 400),
  ('50000000-0000-4000-8000-000000000003', 'TEST03', 'Test', 'Three', 2024, 3000, 'AVAILABLE', 400);

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$select public.assign_vehicle_to_customer('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 1010, now() - interval '3 hours')$$,
  'staff can assign an available vehicle'
);
select is(
  (select operational_status from public.vehicles where id = '50000000-0000-4000-8000-000000000001'),
  'ASSIGNED', 'assigned vehicle becomes ASSIGNED'
);
select throws_ok(
  $$select public.assign_vehicle_to_customer('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 1010, now() - interval '3 hours')$$,
  'P0001', 'vehicle is not available', 'the same vehicle cannot be assigned twice'
);
select throws_ok(
  $$select public.return_vehicle((select id from public.vehicle_assignments where vehicle_id = '50000000-0000-4000-8000-000000000001' and returned_at is null), 1009, now() - interval '2 hours')$$,
  'P0001', 'odometer cannot move backwards', 'return odometer cannot move backwards'
);
select lives_ok(
  $$select public.return_vehicle((select id from public.vehicle_assignments where vehicle_id = '50000000-0000-4000-8000-000000000001' and returned_at is null), 1050, now() - interval '2 hours')$$,
  'an active assignment can be returned'
);
select is(
  (select operational_status from public.vehicles where id = '50000000-0000-4000-8000-000000000001'),
  'AVAILABLE', 'returned vehicle becomes AVAILABLE'
);
select is(
  (select count(*)::integer from public.vehicle_assignments where vehicle_id = '50000000-0000-4000-8000-000000000001'),
  1, 'return preserves assignment history'
);

reset role;
select throws_ok(
  $$insert into public.vehicle_assignments (customer_id, vehicle_id, assigned_at, returned_at, pickup_odometer, return_odometer, assignment_status, created_by)
    values ('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', now() - interval '150 minutes', now() - interval '90 minutes', 1050, 1051, 'RETURNED', '30000000-0000-4000-8000-000000000001')$$,
  '23P01', null, 'database constraint prevents overlapping history'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000001', true);

select public.assign_vehicle_to_customer('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000002', 2010, now() - interval '1 hour');
select lives_ok(
  $$select public.swap_vehicle((select id from public.vehicle_assignments where vehicle_id = '50000000-0000-4000-8000-000000000002' and returned_at is null), '50000000-0000-4000-8000-000000000003', 2020, 3010, now() - interval '30 minutes')$$,
  'active assignment can be swapped to an available vehicle'
);
select is(
  (select count(*)::integer from public.vehicle_assignments where customer_id = '40000000-0000-4000-8000-000000000001' and vehicle_id in ('50000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000003')),
  2, 'swap preserves old and new assignment history'
);
select is(
  (select assignment_status from public.vehicle_assignments where vehicle_id = '50000000-0000-4000-8000-000000000002'),
  'RETURNED', 'swap closes the old assignment'
);
select is(
  (select operational_status from public.vehicles where id = '50000000-0000-4000-8000-000000000003'),
  'ASSIGNED', 'swap assigns the replacement vehicle'
);
select ok(
  (select count(*) >= 1 from public.audit_events where action = 'VEHICLE_SWAPPED'),
  'swap writes an audit event'
);

select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000002', true);
select is((select count(*)::integer from public.vehicles), 0, 'non-staff authenticated users cannot read fleet data');
select throws_ok(
  $$select public.assign_vehicle_to_customer('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 1050)$$,
  '42501', 'staff access required', 'non-staff cannot invoke assignment workflow'
);

select * from finish();
rollback;
