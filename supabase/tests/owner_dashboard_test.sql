begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

create temp table dashboard_baseline as select
  (select count(*) from public.vehicles)::integer fleet_total,
  (select count(*) from public.vehicles where operational_status='AVAILABLE')::integer fleet_available,
  (select count(*) from public.vehicles where operational_status='WORKSHOP')::integer fleet_workshop,
  (select count(*) from public.customer_approvals where status='PENDING')::integer pending_approvals;
grant select on dashboard_baseline to authenticated;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('33000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','dashboard.staff@example.test','',now(),now(),now()),
('33000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','dashboard.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('33000000-0000-4000-8000-000000000001','Synthetic Dashboard Staff','ADMIN');
insert into public.customers(id,full_name,licence_number,status) values
('43000000-0000-4000-8000-000000000001','Synthetic Active Customer','DASH-1','ACTIVE'),
('43000000-0000-4000-8000-000000000002','Synthetic Pending Customer','DASH-2','ACTIVE');
update public.customer_approvals set status='APPROVED',decided_by='33000000-0000-4000-8000-000000000001',decided_at=now() where customer_id='43000000-0000-4000-8000-000000000001';
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) values
('43000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date+10,'33000000-0000-4000-8000-000000000001',now()),
('43000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','VERIFIED',null,'33000000-0000-4000-8000-000000000001',now());
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('53000000-0000-4000-8000-000000000001','DSH001','Synthetic','Rented',2026,20000,'ASSIGNED',100),
('53000000-0000-4000-8000-000000000002','DSH002','Synthetic','Available',2026,19050,'AVAILABLE',100),
('53000000-0000-4000-8000-000000000003','DSH003','Synthetic','Workshop',2026,31001,'WORKSHOP',100),
('53000000-0000-4000-8000-000000000004','DSH004','Synthetic','Offroad',2026,1000,'OFF_ROAD',100);
insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer,status) values
('53000000-0000-4000-8000-000000000002',10000,'OK'),
('53000000-0000-4000-8000-000000000003',20000,'OVERDUE');
insert into public.maintenance_jobs(vehicle_id,status,notes,opened_by) values('53000000-0000-4000-8000-000000000003','OPEN','Synthetic service','33000000-0000-4000-8000-000000000001');
insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,end_date,first_due_date,weekly_amount,created_by) values
('63000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001','WEEKLY_RENTAL','ACTIVE',current_date-7,current_date,current_date-7,100,'33000000-0000-4000-8000-000000000001');
insert into public.payment_schedule_items(agreement_id,sequence_number,due_date,amount_due,status,amount_paid) values
('63000000-0000-4000-8000-000000000001',1,current_date-7,100,'OVERDUE',20),
('63000000-0000-4000-8000-000000000001',2,current_date,100,'DUE',0);
insert into public.payment_transactions(agreement_id,transaction_type,amount,received_at,created_by) values('63000000-0000-4000-8000-000000000001','RECEIPT',20,now(),'33000000-0000-4000-8000-000000000001');
insert into public.operational_exceptions(exception_type,severity,entity_type,entity_id,dedup_key,summary) values
('SERVICE_OVERDUE','HIGH','vehicle','53000000-0000-4000-8000-000000000003','dashboard-service','Synthetic vehicle service overdue'),
('CUSTOMER_APPROVAL','MEDIUM','customer','43000000-0000-4000-8000-000000000002','dashboard-approval','Synthetic customer approval pending');

set local role authenticated;
select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

select is((public.owner_operations_dashboard()->'payments'->>'expected_today')::numeric,100::numeric,'expected-today amount is aggregated');
select is((public.owner_operations_dashboard()->'payments'->>'received_today')::numeric,20::numeric,'received-today amount is aggregated');
select is((public.owner_operations_dashboard()->'payments'->>'overdue_count')::integer,1,'overdue payment items are counted');
select is((public.owner_operations_dashboard()->'payments'->>'overdue_amount')::numeric,80::numeric,'remaining overdue amount is aggregated');
select is((public.owner_operations_dashboard()->'fleet'->>'total')::integer,(select fleet_total+4 from dashboard_baseline),'fleet total is counted');
select is((public.owner_operations_dashboard()->'fleet'->>'rented')::integer,1,'rented fleet is counted');
select is((public.owner_operations_dashboard()->'fleet'->>'available')::integer,(select fleet_available+1 from dashboard_baseline),'available fleet is counted');
select is((public.owner_operations_dashboard()->'fleet'->>'workshop')::integer,(select fleet_workshop+1 from dashboard_baseline),'workshop fleet is counted');
select is((public.owner_operations_dashboard()->'fleet'->>'unavailable')::integer,1,'other unavailable fleet is counted');
select is((public.owner_operations_dashboard()->'maintenance'->>'approaching_service')::integer,1,'approaching service is counted');
select is((public.owner_operations_dashboard()->'maintenance'->>'in_workshop')::integer,(select fleet_workshop+1 from dashboard_baseline),'workshop maintenance is counted');
select is((public.owner_operations_dashboard()->'customers'->>'pending_approval')::integer,(select pending_approvals+1 from dashboard_baseline),'pending approvals are counted');
select is((public.owner_operations_dashboard()->'customers'->>'with_overdue_payments')::integer,1,'overdue customers are counted once');
select is(public.owner_operations_dashboard()->'attention'->0->>'severity','HIGH','attention queue is priority ordered');

select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000002',true);
select is(public.owner_operations_dashboard(),null::jsonb,'non-staff receive no dashboard data');

select * from finish();
rollback;
