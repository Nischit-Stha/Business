begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('35000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','maintenance.admin@example.test','',now(),now(),now()),
('35000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','maintenance.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('35000000-0000-4000-8000-000000000001','Synthetic Maintenance Admin','ADMIN');
insert into public.customers(id,full_name,licence_number,licence_expiry,status) values('45000000-0000-4000-8000-000000000001','Synthetic Expired Driver','MAINT-1',current_date-1,'ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('55000000-0000-4000-8000-000000000001','MNT001','Synthetic','Standard',2026,125000,'AVAILABLE',100),
('55000000-0000-4000-8000-000000000002','MNT002','Synthetic','Override',2026,50000,'AVAILABLE',100),
('55000000-0000-4000-8000-000000000003','MNT003','Synthetic','Compliance',2026,10000,'AVAILABLE',100);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) select v.id,t,'VALID',current_date-10,current_date+365,'35000000-0000-4000-8000-000000000001' from public.vehicles v cross join (values('REGISTRATION'),('RWC')) x(t) where v.id in ('55000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000003');
insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,end_date,first_due_date,weekly_amount,created_by) values('65000000-0000-4000-8000-000000000001','45000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000003','WEEKLY_RENTAL','ACTIVE',current_date-7,current_date+7,current_date-7,100,'35000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

select lives_ok($$select public.create_maintenance_record('55000000-0000-4000-8000-000000000001','SCHEDULED_SERVICE',current_date,null,null,'Synthetic 125k service')$$,'scheduled service record can be created');
select lives_ok($$select public.complete_maintenance_record((select id from public.maintenance_service_records where vehicle_id='55000000-0000-4000-8000-000000000001'),125000,current_date,null,120,'Synthetic completed service')$$,'scheduled service can be completed');
select is((select next_service_odometer from public.maintenance_plans where vehicle_id='55000000-0000-4000-8000-000000000001'),135000,'default next service is 10,000 km after completion');
select is((select next_service_odometer from public.maintenance_service_records where vehicle_id='55000000-0000-4000-8000-000000000001'),135000,'completed history retains calculated next service');
select is((select status from public.vehicle_maintenance_status where vehicle_id='55000000-0000-4000-8000-000000000001'),'OK','vehicle begins below due-soon threshold');
select lives_ok($$select public.record_odometer('55000000-0000-4000-8000-000000000001',133500,'MANUAL',now())$$,'new trusted odometer is accepted');
select is((select status from public.vehicle_maintenance_status where vehicle_id='55000000-0000-4000-8000-000000000001'),'DUE_SOON','within 1,500 km is due soon');
select is((select km_remaining from public.vehicle_maintenance_status where vehicle_id='55000000-0000-4000-8000-000000000001'),1500,'remaining kilometres are calculated');
select lives_ok($$select public.record_odometer('55000000-0000-4000-8000-000000000001',135000,'MANUAL',now())$$,'service threshold odometer is accepted');
select is((select status from public.vehicle_maintenance_status where vehicle_id='55000000-0000-4000-8000-000000000001'),'OVERDUE','service is overdue at the threshold');
select throws_ok($$select public.record_odometer('55000000-0000-4000-8000-000000000001',134999,'MANUAL',now())$$,'P0001','odometer cannot move backwards','older odometer cannot reduce current reading');
select is((select odometer from public.vehicles where id='55000000-0000-4000-8000-000000000001'),135000,'failed older reading leaves current odometer unchanged');

select lives_ok($$select public.set_vehicle_service_interval('55000000-0000-4000-8000-000000000002',7500)$$,'vehicle interval can be overridden');
select lives_ok($$select public.create_maintenance_record('55000000-0000-4000-8000-000000000002','SCHEDULED_SERVICE',current_date,null,null,'Synthetic override service')$$,'override vehicle service can be scheduled');
select lives_ok($$select public.complete_maintenance_record((select id from public.maintenance_service_records where vehicle_id='55000000-0000-4000-8000-000000000002'),50000,current_date,null,null,null)$$,'override vehicle service can be completed');
select is((select next_service_odometer from public.maintenance_plans where vehicle_id='55000000-0000-4000-8000-000000000002'),57500,'manual 7,500 km interval is preserved');

select lives_ok($$select public.set_vehicle_compliance('55000000-0000-4000-8000-000000000003','REGISTRATION','EXPIRED',current_date-365,current_date-1)$$,'expired registration can be recorded');
select lives_ok($$select public.set_vehicle_compliance('55000000-0000-4000-8000-000000000003','RWC','EXPIRING_SOON',current_date-300,current_date+7)$$,'expiring RWC can be recorded');
select is((select exposure from public.vehicle_compliance_exposure where vehicle_id='55000000-0000-4000-8000-000000000003' and compliance_type='REGISTRATION'),'EXPIRED','registration exposure derives expiry');
select is((select exposure from public.vehicle_compliance_exposure where vehicle_id='55000000-0000-4000-8000-000000000003' and compliance_type='RWC'),'DUE_7','RWC seven-day threshold is derived');
select isnt((select ready_for_allocation from public.fleet_operations where id='55000000-0000-4000-8000-000000000003'),true,'expired registration blocks fleet readiness');
select lives_ok($$select public.refresh_maintenance_compliance_attention()$$,'attention automation runs');
select ok(exists(select 1 from public.operational_exceptions where dedup_key='auto-compliance:registration:55000000-0000-4000-8000-000000000003' and severity='CRITICAL' and status<>'RESOLVED'),'expired registration creates critical attention');
select ok(exists(select 1 from public.operational_exceptions where dedup_key='auto-compliance:rwc:55000000-0000-4000-8000-000000000003' and status<>'RESOLVED'),'RWC expiry creates attention');
select ok(exists(select 1 from public.operational_exceptions where dedup_key='auto-licence:45000000-0000-4000-8000-000000000001' and severity='HIGH' and status<>'RESOLVED'),'expired licence on active agreement creates high attention');
select ok(exists(select 1 from public.operational_exceptions where dedup_key='auto-service:55000000-0000-4000-8000-000000000001' and status<>'RESOLVED'),'overdue service creates deduplicated attention');
select ok((public.owner_operations_dashboard()->'attention') @> jsonb_build_array(jsonb_build_object('type','SERVICE_OVERDUE')),'overdue service appears in owner attention');

select lives_ok($$select public.create_maintenance_record('55000000-0000-4000-8000-000000000001','SCHEDULED_SERVICE',current_date,null,null,'Synthetic overdue service')$$,'overdue replacement service can be recorded');
select lives_ok($$select public.complete_maintenance_record((select id from public.maintenance_service_records where vehicle_id='55000000-0000-4000-8000-000000000001' and status='SCHEDULED'),135000,current_date,null,null,'Synthetic overdue service completed')$$,'overdue service can be completed');

select lives_ok($$select public.set_vehicle_compliance('55000000-0000-4000-8000-000000000003','REGISTRATION','VALID',current_date,current_date+365)$$,'registration can be renewed');
select lives_ok($$select public.refresh_maintenance_compliance_attention()$$,'renewal refresh runs');
select ok(exists(select 1 from public.operational_exceptions where dedup_key='auto-compliance:registration:55000000-0000-4000-8000-000000000003' and status='RESOLVED'),'renewal automatically closes registration attention');
select ok(exists(select 1 from public.operational_exceptions where dedup_key='auto-service:55000000-0000-4000-8000-000000000001' and status='RESOLVED'),'completed service automatically closes overdue attention');

select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.maintenance_service_records),0,'non-staff cannot read service history');
select throws_ok($$select public.set_vehicle_service_interval('55000000-0000-4000-8000-000000000001',10000)$$,'42501','staff access required','non-staff cannot change service intervals');

select * from finish();
rollback;
