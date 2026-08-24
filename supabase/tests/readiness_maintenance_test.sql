begin;
create extension if not exists pgtap with schema extensions;
select plan(18);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('33000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','readiness.admin@example.test','',now(),now(),now()),
('33000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','readiness.staff@example.test','',now(),now(),now()),
('33000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','readiness.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values
('33000000-0000-4000-8000-000000000001','Synthetic Admin','ADMIN'),('33000000-0000-4000-8000-000000000002','Synthetic Staff','STAFF');
insert into public.customers(id,full_name,licence_number,status) values('43000000-0000-4000-8000-000000000001','Synthetic Ready Customer','READY-1','ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('53000000-0000-4000-8000-000000000001','RDY001','Synthetic','One',2025,1000,'AVAILABLE',100),
('53000000-0000-4000-8000-000000000002','RDY002','Synthetic','Two',2025,5000,'AVAILABLE',100);
set local role authenticated; select set_config('request.jwt.claim.role','authenticated',true); select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.assign_vehicle_to_customer('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',1000)$$,'P0001','customer prerequisites are incomplete','unapproved customer blocked');
select public.decide_customer_approval('43000000-0000-4000-8000-000000000001','APPROVED');
select throws_ok($$select public.assign_vehicle_to_customer('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',1000)$$,'P0001','customer prerequisites are incomplete','verified documents required');
select public.set_customer_document('43000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date-1);
select public.set_customer_document('43000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','VERIFIED',null);
select is((select ready from public.customer_readiness where customer_id='43000000-0000-4000-8000-000000000001'),false,'expired licence blocks readiness');
select public.set_customer_document('43000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date+365);
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000001','REGISTRATION','EXPIRED',current_date-365,current_date-1);
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000001','RWC','VALID',current_date,current_date+365);
select throws_ok($$select public.assign_vehicle_to_customer('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',1000)$$,'P0001','vehicle compliance is incomplete or expired','expired registration blocks pickup');
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000001','REGISTRATION','VALID',current_date,current_date+365);
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000001','RWC','MISSING',null,null);
select throws_ok($$select public.assign_vehicle_to_customer('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',1000)$$,'P0001','vehicle compliance is incomplete or expired','missing RWC blocks pickup');
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000001','RWC','EXPIRED',current_date-365,current_date-1);
select throws_ok($$select public.assign_vehicle_to_customer('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',1000)$$,'P0001','vehicle compliance is incomplete or expired','expired RWC blocks pickup');
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000001','RWC','VALID',current_date,current_date+365);
select lives_ok($$select public.assign_vehicle_to_customer('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',1100)$$,'successful pickup readiness');
select ok((select count(*)>0 from public.audit_events where action='CUSTOMER_APPROVED' and entity_id='43000000-0000-4000-8000-000000000001'),'approval decision is audited');
select public.create_return_checklist((select id from public.vehicle_assignments where vehicle_id='53000000-0000-4000-8000-000000000001'));
select lives_ok($$select public.complete_return((select id from public.return_checklists),1200,'GOOD',false,'RELEASE')$$,'return completes');
select is((select count(*)::integer from public.vehicle_assignments where vehicle_id='53000000-0000-4000-8000-000000000001'),1,'return preserves assignment history');
select throws_ok($$select public.record_odometer('53000000-0000-4000-8000-000000000001',1199,'MANUAL')$$,'P0001','odometer cannot move backwards','odometer cannot decrease');
set local role postgres;
insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer) values('53000000-0000-4000-8000-000000000002',5000);
set local role authenticated;
select is((select next_service_odometer from public.maintenance_plans where vehicle_id='53000000-0000-4000-8000-000000000002'),15000,'10,000 km threshold calculated');
select public.record_odometer('53000000-0000-4000-8000-000000000002',15000,'MANUAL');
select is((select status from public.vehicle_maintenance_status where vehicle_id='53000000-0000-4000-8000-000000000002'),'DUE','service due detected');
select public.open_maintenance_job('53000000-0000-4000-8000-000000000002','Synthetic service');
select public.complete_maintenance_job((select id from public.maintenance_jobs where vehicle_id='53000000-0000-4000-8000-000000000002'),15100,'Complete',125);
select is((select next_service_odometer from public.maintenance_plans where vehicle_id='53000000-0000-4000-8000-000000000002'),25100,'completed service advances threshold');
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000002','REGISTRATION','EXPIRED',current_date-365,current_date-1);
select public.set_vehicle_compliance('53000000-0000-4000-8000-000000000002','RWC','EXPIRED',current_date-365,current_date-1);
select public.record_odometer('53000000-0000-4000-8000-000000000002',26100,'MANUAL');
select public.refresh_readiness_exceptions(); select public.refresh_readiness_exceptions();
select is((select count(*)::integer from public.operational_exceptions where dedup_key in ('registration:53000000-0000-4000-8000-000000000002','rwc:53000000-0000-4000-8000-000000000002','service:53000000-0000-4000-8000-000000000002')),3,'service/rego/RWC exceptions deduplicate');
select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.decide_customer_approval('43000000-0000-4000-8000-000000000001','SUSPENDED')$$,'42501','admin access required','staff cannot bypass approval');
select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000003',true);
select is((select count(*)::integer from public.customer_approvals),0,'unauthorized approval reads denied');
select throws_ok($$select public.record_odometer('53000000-0000-4000-8000-000000000002',27000,'MANUAL')$$,'42501','staff access required','unauthorized workflow denied');
select * from finish(); rollback;
