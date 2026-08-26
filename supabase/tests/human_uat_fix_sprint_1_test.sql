begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('3f000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','huat.admin@example.test','',now(),now(),now()),
('3f000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','huat.customer@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('3f000000-0000-4000-8000-000000000001','Synthetic HUAT Admin','ADMIN');
insert into public.customers(id,full_name,licence_number,status) values('4f000000-0000-4000-8000-000000000001','Synthetic HUAT Customer','HUAT-1','ACTIVE');
insert into public.customer_portal_accounts(user_id,customer_id,status,created_by) values('3f000000-0000-4000-8000-000000000002','4f000000-0000-4000-8000-000000000001','ACTIVE','3f000000-0000-4000-8000-000000000001');
update public.customer_approvals set status='APPROVED',decided_by='3f000000-0000-4000-8000-000000000001',decided_at=now() where customer_id='4f000000-0000-4000-8000-000000000001';
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) values
('4f000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date+365,'3f000000-0000-4000-8000-000000000001',now()),
('4f000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','VERIFIED',null,'3f000000-0000-4000-8000-000000000001',now());
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values('5f000000-0000-4000-8000-000000000001','HUAT01','Synthetic','Handover',2026,1000,'PICKUP_PENDING',100);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) values
('5f000000-0000-4000-8000-000000000001','REGISTRATION','VALID',current_date,current_date+365,'3f000000-0000-4000-8000-000000000001'),
('5f000000-0000-4000-8000-000000000001','RWC','VALID',current_date,current_date+365,'3f000000-0000-4000-8000-000000000001');
insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,first_due_date,weekly_amount,created_by) values('6f000000-0000-4000-8000-000000000001','4f000000-0000-4000-8000-000000000001','5f000000-0000-4000-8000-000000000001','WEEKLY_RENTAL','ACTIVE',current_date,current_date,100,'3f000000-0000-4000-8000-000000000001');
insert into public.pickup_checklists(id,agreement_id,customer_id,vehicle_id,status,scheduled_at) values('7f000000-0000-4000-8000-000000000001','6f000000-0000-4000-8000-000000000001','4f000000-0000-4000-8000-000000000001','5f000000-0000-4000-8000-000000000001','READY',now());

set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','3f000000-0000-4000-8000-000000000001',true);
select is(public.change_account_access('3f000000-0000-4000-8000-000000000002','CUSTOMER',false),'DISABLED','portal revoke succeeds');
select is((select status from public.customer_portal_accounts where user_id='3f000000-0000-4000-8000-000000000002'),'DISABLED','portal relationship is retained but disabled');
select ok((select count(*)=1 from public.account_security_events where subject_user_id='3f000000-0000-4000-8000-000000000002' and event_type='ACCOUNT_DISABLED'),'disable security history is retained');
select ok((select count(*)=1 from public.audit_events where entity_id='4f000000-0000-4000-8000-000000000001' and action='CUSTOMER_PORTAL_ACCESS_CHANGED'),'portal audit history is retained');
select is(public.change_account_access('3f000000-0000-4000-8000-000000000002','CUSTOMER',true),'ENABLED','portal access can be restored');
select throws_ok($$select public.change_account_access('00000000-0000-4000-8000-000000000099','CUSTOMER',false)$$,'P0001','customer portal account not found','failed revoke leaves a recoverable error');
select throws_ok($$select public.assign_vehicle_to_customer('4f000000-0000-4000-8000-000000000001','5f000000-0000-4000-8000-000000000001',1000)$$,'55000','direct custody assignment is disabled; schedule and complete a pickup handover','direct assignment cannot create custody');
select throws_ok($$select public.complete_pickup('7f000000-0000-4000-8000-000000000001',1000,now(),false)$$,'P0001','confirm that keys and vehicle were handed over','handover confirmation is required');
select is((select count(*)::integer from public.vehicle_assignments),0,'failed handover creates no custody');
select lives_ok($$select public.complete_pickup('7f000000-0000-4000-8000-000000000001',1000,now(),true)$$,'confirmed pickup completes');
select ok((select assignment_status='ACTIVE' and assigned_at is not null from public.vehicle_assignments where vehicle_id='5f000000-0000-4000-8000-000000000001'),'custody begins at completed handover');
select public.create_return_checklist((select id from public.vehicle_assignments where vehicle_id='5f000000-0000-4000-8000-000000000001'));
select lives_ok($$select public.complete_return((select id from public.return_checklists),1010,'GOOD',false,'RELEASE')$$,'return completes with derived state');
select is((select operational_status from public.vehicles where id='5f000000-0000-4000-8000-000000000001'),'OFF_ROAD','active agreement prevents returned vehicle becoming available');

select * from finish();rollback;
