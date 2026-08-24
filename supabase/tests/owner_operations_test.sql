begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('32000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner.admin@example.test','',now(),now(),now()),
('32000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('32000000-0000-4000-8000-000000000001','Synthetic Owner','ADMIN');
insert into public.customers(id,full_name,licence_number,status) values('42000000-0000-4000-8000-000000000001','Synthetic Swap Customer','SWAP-1','ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('52000000-0000-4000-8000-000000000001','SWP001','Synthetic','Old',2025,1000,'AVAILABLE',100),
('52000000-0000-4000-8000-000000000002','SWP002','Synthetic','New',2025,2000,'AVAILABLE',100),
('52000000-0000-4000-8000-000000000003','SWP003','Synthetic','Busy',2025,3000,'AVAILABLE',100),
('52000000-0000-4000-8000-000000000004','SWP004','Synthetic','Open',2025,4000,'AVAILABLE',100);
insert into public.customer_approvals(customer_id,status,decided_by,decided_at) select id,'APPROVED','32000000-0000-4000-8000-000000000001',now() from public.customers on conflict(customer_id) do update set status='APPROVED',decided_by=excluded.decided_by,decided_at=excluded.decided_at;
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) select c.id,t,'VERIFIED',current_date+365,'32000000-0000-4000-8000-000000000001',now() from public.customers c cross join (values('DRIVER_LICENCE'),('PROOF_OF_ADDRESS')) d(t);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) select v.id,t,'VALID',current_date-1,current_date+365,'32000000-0000-4000-8000-000000000001' from public.vehicles v cross join (values('REGISTRATION'),('RWC')) x(t);

set local role authenticated;
select set_config('request.jwt.claim.sub','32000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select public.assign_vehicle_to_customer('42000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001',1000,now()-interval '20 days');
select public.create_agreement('42000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date-14,null,current_date-14,100);
select public.transition_agreement((select id from public.agreements where vehicle_id='52000000-0000-4000-8000-000000000001'),'PENDING_SIGNATURE');
select public.transition_agreement((select id from public.agreements where vehicle_id='52000000-0000-4000-8000-000000000001'),'ACTIVE');
select public.record_manual_payment((select id from public.agreements where vehicle_id='52000000-0000-4000-8000-000000000001'),100,now()-interval '1 hour','SWAP-PAYMENT','Synthetic');

create temp table before_counts as select
  (select count(*) from public.payment_transactions)::integer payments,
  (select count(*) from public.payment_schedule_items)::integer schedule;
select lives_ok($$select public.swap_active_agreement_vehicle((select id from public.agreements where status='ACTIVE'),'52000000-0000-4000-8000-000000000002',1100,2000)$$,'active agreement vehicle swaps successfully');
select is((select operational_status from public.vehicles where id='52000000-0000-4000-8000-000000000001'),'AVAILABLE','old vehicle becomes available');
select is((select operational_status from public.vehicles where id='52000000-0000-4000-8000-000000000002'),'ASSIGNED','new vehicle becomes assigned');
select is((select vehicle_id from public.agreements where status='ACTIVE'),'52000000-0000-4000-8000-000000000002'::uuid,'agreement vehicle changes');
select is((select count(*)::integer from public.payment_transactions),(select payments from before_counts),'payment history is unchanged');
select is((select count(*)::integer from public.payment_schedule_items),(select schedule from before_counts),'schedule is unchanged');
select is((select count(*)::integer from public.vehicle_assignments where customer_id='42000000-0000-4000-8000-000000000001'),2,'assignment history is preserved');

select public.assign_vehicle_to_customer('42000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000003',3000);
select throws_ok($$select public.swap_active_agreement_vehicle((select id from public.agreements where status='ACTIVE'),'52000000-0000-4000-8000-000000000003',1200,3000)$$,'P0001','replacement vehicle is not available','unavailable target is blocked');
select throws_ok($$select public.swap_active_agreement_vehicle((select id from public.agreements where status='ACTIVE'),'52000000-0000-4000-8000-000000000004',900,4000)$$,'P0001','odometer cannot move backwards','failed swap rejects odometer rollback');
select ok((select vehicle_id='52000000-0000-4000-8000-000000000002' from public.agreements where status='ACTIVE') and
  (select operational_status='ASSIGNED' from public.vehicles where id='52000000-0000-4000-8000-000000000002') and
  (select operational_status='AVAILABLE' from public.vehicles where id='52000000-0000-4000-8000-000000000004'),'failed swap rolls back completely');

select ok((select failures=0 from public.run_open_agreement_schedule_extension(12)) and
  (select max(due_date)>=current_date+interval '12 weeks' from public.payment_schedule_items),'open schedule extension maintains the future horizon');
select is((select items_created from public.run_open_agreement_schedule_extension(12)),0,'schedule extension is idempotent');
select public.transition_agreement((select id from public.agreements where status='ACTIVE'),'COMPLETED');
select is((select agreements_checked from public.run_open_agreement_schedule_extension(12)),0,'completed agreements are ignored');
select public.create_agreement('42000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000004','WEEKLY_RENTAL',current_date,null,current_date,100);
select public.transition_agreement((select id from public.agreements where status='DRAFT'),'CANCELLED');
select is((select agreements_checked from public.run_open_agreement_schedule_extension(12)),0,'cancelled agreements are ignored');

select public.report_vehicle_swap_failure((select id from public.agreements limit 1),'Synthetic failure');
select public.report_vehicle_swap_failure((select id from public.agreements limit 1),'Synthetic failure updated');
select is((select count(*)::integer from public.operational_exceptions where exception_type='VEHICLE_SWAP_FAILURE'),1,'open exceptions are deduplicated');
select lives_ok($$select public.assign_exception((select id from public.operational_exceptions limit 1),'32000000-0000-4000-8000-000000000001')$$,'exception can be assigned');
select lives_ok($$select public.resolve_exception((select id from public.operational_exceptions limit 1),'Reviewed synthetic failure')$$,'exception can be resolved');
select is((select status from public.operational_exceptions limit 1),'RESOLVED','exception resolution is durable');

select set_config('request.jwt.claim.sub','32000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.operational_exceptions),0,'unauthorized user cannot read exceptions');
select throws_ok($$select public.swap_active_agreement_vehicle('00000000-0000-0000-0000-000000000000','52000000-0000-4000-8000-000000000004',1,4000)$$,'42501','staff access required','unauthorized swap is denied');
select throws_ok($$select public.resolve_exception('00000000-0000-0000-0000-000000000000','No')$$,'42501','staff access required','unauthorized exception workflow is denied');

select * from finish();
rollback;
