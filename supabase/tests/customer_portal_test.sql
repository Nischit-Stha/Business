begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('36000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','portal.staff@example.test','',now(),now(),now()),
('36000000-0000-4000-8000-000000000002','00000000-0000-0000-8000-000000000000','authenticated','authenticated','portal.one@example.test','',now(),now(),now()),
('36000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','portal.two@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('36000000-0000-4000-8000-000000000001','Synthetic Portal Staff','ADMIN');
insert into public.customers(id,full_name,phone,email,licence_number,licence_expiry,status) values
('46000000-0000-4000-8000-000000000001','Synthetic Portal One','+61400000301','portal.one@example.test','PORTAL-1',current_date+14,'ACTIVE'),
('46000000-0000-4000-8000-000000000002','Synthetic Portal Two','+61400000302','portal.two@example.test','PORTAL-2',current_date+30,'ACTIVE');
insert into public.customer_portal_accounts(user_id,customer_id,created_by) values
('36000000-0000-4000-8000-000000000002','46000000-0000-4000-8000-000000000001','36000000-0000-4000-8000-000000000001'),
('36000000-0000-4000-8000-000000000003','46000000-0000-4000-8000-000000000002','36000000-0000-4000-8000-000000000001');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('56000000-0000-4000-8000-000000000001','PTL001','Synthetic','Portal One',2025,9000,'ASSIGNED',100),
('56000000-0000-4000-8000-000000000002','PTL002','Synthetic','Portal Two',2025,5000,'ASSIGNED',120);
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values
('66000000-0000-4000-8000-000000000001','46000000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000001',now()-interval '30 days',1,'ACTIVE','36000000-0000-4000-8000-000000000001'),
('66000000-0000-4000-8000-000000000002','46000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000002',now()-interval '20 days',1,'ACTIVE','36000000-0000-4000-8000-000000000001');
insert into public.maintenance_plans(vehicle_id,service_interval_km,last_completed_service_odometer,status) values('56000000-0000-4000-8000-000000000001',10000,0,'OK');
insert into public.customer_documents(customer_id,document_type,status,expiry_date) values
('46000000-0000-4000-8000-000000000001','DRIVER_LICENCE','SUBMITTED',current_date+14),
('46000000-0000-4000-8000-000000000002','DRIVER_LICENCE','SUBMITTED',current_date+30);

set local role authenticated; select set_config('request.jwt.claim.sub','36000000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claim.role','authenticated',true);
select public.create_agreement('46000000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date-14,current_date+14,current_date-7,100);
select public.transition_agreement((select id from public.agreements where customer_id='46000000-0000-4000-8000-000000000001'),'PENDING_SIGNATURE');
select public.transition_agreement((select id from public.agreements where customer_id='46000000-0000-4000-8000-000000000001'),'ACTIVE');
select public.record_manual_payment((select id from public.agreements where customer_id='46000000-0000-4000-8000-000000000001'),100,now(),'INTERNAL-REF-NOT-FOR-PORTAL','Synthetic safe payment');
reset role;
select app_private.queue_notification('portal-safe-notification','PAYMENT_DUE','46000000-0000-4000-8000-000000000001','{"customer_first_name":"Synthetic","amount":"100.00","due_date":"today"}',now(),'36000000-0000-4000-8000-000000000001');
select app_private.queue_notification('portal-internal-notification','PAYMENT_DUE','46000000-0000-4000-8000-000000000002','{"customer_first_name":"Synthetic","amount":"120.00","due_date":"today"}',now(),'36000000-0000-4000-8000-000000000001');
update public.notifications set channel='INTERNAL' where dedup_key='portal-internal-notification';

set local role authenticated; select set_config('request.jwt.claim.sub','36000000-0000-4000-8000-000000000002',true);
select is((select count(*)::int from public.portal_profile),1,'customer can access own profile');
select is((select customer_id from public.portal_profile),'46000000-0000-4000-8000-000000000001'::uuid,'profile is linked to authenticated customer');
select is((select count(*)::int from public.customers where id='46000000-0000-4000-8000-000000000001'),0,'customer cannot bypass projection to read own sensitive base row');
select is((select count(*)::int from public.customers where id='46000000-0000-4000-8000-000000000002'),0,'customer cannot read another profile by direct id');
select is((select count(*)::int from public.portal_agreements),1,'customer can access own agreement');
select is((select count(*)::int from public.agreements),0,'customer cannot query agreement base columns directly');
select is((select count(*)::int from public.agreements where customer_id='46000000-0000-4000-8000-000000000002'),0,'cross-customer agreement access denied');
select is((select count(*)::int from public.vehicles where id='56000000-0000-4000-8000-000000000002'),0,'cross-customer vehicle direct-object access denied');
select is((select count(*)::int from public.portal_payment_schedule)>0,true,'own payment schedule is visible');
select is((select count(*)::int from public.payment_transactions),0,'raw payment ledger remains inaccessible');
select hasnt_column('public','portal_payment_receipts','reference','receipt view omits raw payment references');
select hasnt_column('public','portal_payment_receipts','notes','receipt view omits staff notes');
select is((select customer_reference from public.portal_payment_receipts limit 1),'Payment received','receipt uses sanitized customer reference');
select is((select count(*)::int from public.portal_documents),1,'own document status is visible');
select is((select count(*)::int from public.customer_documents where customer_id='46000000-0000-4000-8000-000000000002'),0,'other customer document denied');
select hasnt_column('public','portal_documents','storage_object_path','document view contains no storage path');
select lives_ok($$select public.submit_customer_portal_issue('WARNING_LIGHT','Synthetic warning appeared','MEDIUM','Synthetic safe note')$$,'customer can submit controlled issue');
reset role;
select is((select source from public.vehicle_issues where source='CUSTOMER_PORTAL'),'CUSTOMER_PORTAL','issue source identifies customer portal');
select is((select status from public.vehicle_issues where source='CUSTOMER_PORTAL'),'OPEN','customer cannot choose internal workflow state');
select is((select assigned_to from public.vehicle_issues where source='CUSTOMER_PORTAL'),null,'customer cannot choose assignee');
select is((select vehicle_id from public.vehicle_issues where source='CUSTOMER_PORTAL'),'56000000-0000-4000-8000-000000000001'::uuid,'issue automatically links own vehicle');
set local role authenticated; select set_config('request.jwt.claim.sub','36000000-0000-4000-8000-000000000002',true);
select hasnt_column('public','portal_issues','assigned_to','issue view hides internal assignee');
select hasnt_column('public','portal_issues','resolution','issue view hides staff resolution commentary');
select is((select count(*)::int from public.portal_notifications),2,'customer sees own non-internal notifications including payment receipt');
select is((select count(*)::int from public.notifications),0,'raw notification rows remain inaccessible');
select hasnt_column('public','portal_notifications','provider_message_id','notification history hides provider metadata');
select hasnt_column('public','portal_notifications','failure_reason','notification history hides failure details');
select hasnt_column('public','portal_maintenance','cost','maintenance view hides costs');
select hasnt_column('public','portal_maintenance','notes','maintenance view hides internal notes');
select is((select count(*)::int from public.portal_payment_instructions),0,'unapproved payment instructions produce neutral empty state');
select throws_ok($$select public.request_portal_reschedule('PICKUP','00000000-0000-4000-8000-000000000001',now()+interval '1 day')$$,'P0001','active pickup not found','direct-object reschedule attempt denied');

select * from finish(); rollback;
