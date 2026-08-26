begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('30000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@example.test', '', now(), now(), now()),
  ('30000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider@example.test', '', now(), now(), now()),
  ('30000000-0000-4000-8000-000000000003', '00000000-0000-0000-8000-000000000000', 'authenticated', 'authenticated', 'disabled@example.test', '', now(), now(), now());
insert into public.staff_profiles (user_id, full_name)
values ('30000000-0000-4000-8000-000000000001', 'Synthetic Staff');
insert into public.staff_profiles (user_id, full_name, status, is_active)
values ('30000000-0000-4000-8000-000000000003', 'Disabled Synthetic Staff', 'DISABLED', false);
insert into public.customers (id, full_name, licence_number, status)
values ('40000000-0000-4000-8000-000000000001', 'Test Customer', 'TEST-LICENCE-001', 'ACTIVE');
insert into public.vehicles (id, registration, make, model, year, odometer, operational_status, weekly_rate)
values
  ('50000000-0000-4000-8000-000000000001', 'TEST01', 'Test', 'One', 2024, 1000, 'AVAILABLE', 400),
  ('50000000-0000-4000-8000-000000000002', 'TEST02', 'Test', 'Two', 2024, 2000, 'AVAILABLE', 400),
  ('50000000-0000-4000-8000-000000000003', 'TEST03', 'Test', 'Three', 2024, 3000, 'AVAILABLE', 400);

insert into public.customer_approvals(customer_id,status,decided_by,decided_at) select id,'APPROVED','30000000-0000-4000-8000-000000000001',now() from public.customers on conflict(customer_id) do update set status='APPROVED',decided_by=excluded.decided_by,decided_at=excluded.decided_at;
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) select c.id,t,'VERIFIED',current_date+365,'30000000-0000-4000-8000-000000000001',now() from public.customers c cross join (values('DRIVER_LICENCE'),('PROOF_OF_ADDRESS')) d(t);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) select v.id,t,'VALID',current_date-1,current_date+365,'30000000-0000-4000-8000-000000000001' from public.vehicles v cross join (values('REGISTRATION'),('RWC')) x(t);
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$select public.assign_vehicle_to_customer('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 1010, now() - interval '3 hours')$$,
  '55000','direct custody assignment is disabled; schedule and complete a pickup handover','direct assignment cannot start custody'
);
select is(
  (select operational_status from public.vehicles where id = '50000000-0000-4000-8000-000000000001'),
  'AVAILABLE', 'planning does not change physical custody state'
);
select is((select count(*)::integer from public.vehicle_assignments),0,'planning creates no custody row');
set local role postgres;
insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001',now()-interval '3 hours',1010,'ACTIVE','30000000-0000-4000-8000-000000000001');
update public.vehicles set operational_status='ASSIGNED',odometer=1010 where id='50000000-0000-4000-8000-000000000001';
set local role authenticated;select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
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

set local role postgres;
insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000002',now()-interval '1 hour',2010,'ACTIVE','30000000-0000-4000-8000-000000000001');
update public.vehicles set operational_status='ASSIGNED',odometer=2010 where id='50000000-0000-4000-8000-000000000002';
set local role authenticated;select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
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

select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000003', true);
select is((select count(*)::integer from public.customers), 0, 'disabled staff cannot read customer data');
select throws_ok(
  $$select public.create_customer('Denied Person','0400 000 999','denied@example.test','DENIED-1','2030-01-01','1 Denied Street')$$,
  '42501', 'staff access required', 'disabled staff cannot create customers'
);

select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$select public.create_customer('Casey Synthetic','0400 000 333','casey@example.test','SYN-C333','2031-03-01','3 Synthetic Street')$$,
  'staff can create a valid customer'
);
select throws_ok(
  $$select public.create_customer('Invalid','bad','bad','SYN-BAD','2031-03-01','3 Synthetic Street')$$,
  '22023', 'invalid phone', 'customer validation rejects invalid phone'
);
select lives_ok(
  $$select public.update_customer((select id from public.customers where licence_number='SYN-C333'),'Casey Synthetic Updated','0400 000 334','casey.updated@example.test','SYN-C333','2032-03-01','4 Synthetic Street')$$,
  'staff can update a customer'
);
select lives_ok(
  $$select public.change_customer_status((select id from public.customers where licence_number='SYN-C333'),'BLOCKED')$$,
  'staff can change customer status'
);
select ok((select count(*) >= 3 from public.audit_events where entity_type='customer'), 'customer changes create audit events');

select lives_ok(
  $$select public.create_vehicle('SYN900','SYNTHVIN900','Synthetic','Sedan',2025,10,450,'AVAILABLE')$$,
  'staff can create a vehicle'
);
select throws_ok(
  $$select public.create_vehicle('syn900','SYNTHVIN901','Synthetic','Sedan',2025,10,450,'AVAILABLE')$$,
  '23505', null, 'duplicate registration is blocked case-insensitively'
);
select lives_ok(
  $$select public.update_vehicle((select id from public.vehicles where registration='SYN900'),'SYN900','SYNTHVIN900','Synthetic','Wagon',2025,20,475,'WORKSHOP')$$,
  'staff can update non-assignment vehicle information'
);
select throws_ok(
  $$select public.update_vehicle((select id from public.vehicles where registration='SYN900'),'SYN900','SYNTHVIN900','Synthetic','Wagon',2025,20,475,'ASSIGNED')$$,
  '42501', 'assignment state is workflow controlled', 'vehicle update cannot fake assigned state'
);
select ok((select count(*) >= 2 from public.audit_events where entity_type='vehicle' and action in ('VEHICLE_CREATED','VEHICLE_EDITED')), 'vehicle changes create audit events');
select throws_ok(
  $$update public.vehicles set operational_status='ASSIGNED' where registration='SYN900'$$,
  '42501', null, 'authenticated browser role cannot write vehicles directly'
);

select * from finish();
rollback;
