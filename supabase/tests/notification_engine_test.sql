begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('35000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','notify.staff@example.test','',now(),now(),now()),
('35000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','notify.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('35000000-0000-4000-8000-000000000001','Synthetic Notification Staff','ADMIN');
insert into public.customers(id,full_name,phone,email,licence_number,licence_expiry,status) values('45000000-0000-4000-8000-000000000001','Synthetic Driver','+61400000201','notify@example.test','NOTIFY-1',current_date+7,'ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values('55000000-0000-4000-8000-000000000001','NTF001','Synthetic','Vehicle',2025,10500,'ASSIGNED',100);
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('65000000-0000-4000-8000-000000000001','45000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001',now()-interval '30 days',1,'ACTIVE','35000000-0000-4000-8000-000000000001');
insert into public.maintenance_plans(vehicle_id,service_interval_km,last_completed_service_odometer,status) values('55000000-0000-4000-8000-000000000001',10000,0,'OVERDUE');

set local role authenticated;
select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select public.create_agreement('45000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date-14,current_date+14,current_date-7,100);
select public.transition_agreement((select id from public.agreements),'PENDING_SIGNATURE');
select public.transition_agreement((select id from public.agreements),'ACTIVE');
select lives_ok($$select public.generate_notifications(now())$$,'generates payment, maintenance, and licence stages');
select cmp_ok((select count(*) from public.notifications),' >= ',3::bigint,'automation creates relevant reminders');
select public.generate_notifications(now());
select is((select count(*) from public.notifications),(select count(distinct dedup_key) from public.notifications),'deduplication keys prevent repeat reminders');
select cmp_ok((select count(*)::int from public.notifications where type='PAYMENT_OVERDUE' and dedup_key like '%:1'),'>=',1,'one-day overdue escalation generated');
select cmp_ok((select count(*)::int from public.notifications where type='PAYMENT_OVERDUE' and dedup_key like '%:3'),'>=',1,'three-day overdue escalation generated');
select cmp_ok((select count(*)::int from public.notifications where type='PAYMENT_OVERDUE' and dedup_key like '%:7'),'>=',1,'seven-day overdue escalation generated');
select is((select count(*)::int from public.notifications where type='LICENCE_EXPIRING' and dedup_key like '%:7'),1,'licence seven-day stage generated');
select is((select count(*)::int from public.notifications where type='SERVICE_OVERDUE'),1,'maintenance overdue condition generates once');

select public.schedule_pickup((select id from public.agreements),now()+interval '1 hour');
select public.generate_notifications(now());
select is((select count(*)::int from public.notifications where type='PICKUP_REMINDER'),2,'pickup reminder stages generated from explicit schedule');
reset role;
update public.pickup_checklists set status='CANCELLED' where agreement_id=(select id from public.agreements);
set local role authenticated; select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000001',true);
select public.generate_notifications(now());
select is((select count(*)::int from public.notifications where type='PICKUP_REMINDER' and status='CANCELLED'),2,'pickup completion or cancellation cancels future work');

create temporary table first_claim as select * from public.claim_notifications(1,60);
create temporary table second_claim as select * from public.claim_notifications(100,60);
select is((select count(*)::int from first_claim a join second_claim b using(id)),0,'leases and skip locked prevent duplicate claims');
select throws_ok($$select public.complete_notification(id,gen_random_uuid(),'SUCCESS','local:x') from first_claim$$,'P0001','active notification claim not found','wrong claim token cannot complete work');
select lives_ok($$select public.complete_notification(id,claim_token,'SUCCESS','local:'||id) from first_claim$$,'claimed work completes idempotently');
select is((select status from public.notifications where id=(select id from first_claim)),'SENT','successful delivery preserves sent history');

reset role;
select app_private.queue_notification('retry-test','PAYMENT_DUE','45000000-0000-4000-8000-000000000001','{"customer_first_name":"Synthetic","amount":"10.00","due_date":"today"}',now(),'35000000-0000-4000-8000-000000000001');
update public.notifications set max_retries=1 where dedup_key='retry-test';
set local role authenticated; select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000001',true);
create temporary table retry_claim as select * from public.claim_notifications(100,60);
select public.complete_notification(id,claim_token,'TEMPORARY_FAILURE',null,'simulated') from retry_claim where dedup_key='retry-test';
select is((select status from public.notifications where dedup_key='retry-test'),'FAILED','bounded retry limit reaches failed state');
select is((select count(*)::int from public.operational_exceptions where dedup_key like 'notification-failure:%'),1,'repeated failure creates meaningful owner attention');
reset role;
select throws_ok($$select app_private.render_notification('Hi {{unsafe}}','{"unsafe":"x"}','{customer_first_name}')$$,'22023','unsafe template variable: unsafe','template allow-list rejects unsafe variables');
set local role authenticated; select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000001',true);
reset role;
select throws_ok($$update public.notifications set rendered_message='changed' where status='SENT'$$,'42501','sent notification history is immutable','sent message content cannot be edited');

set local role authenticated;
select set_config('request.jwt.claim.sub','35000000-0000-4000-8000-000000000002',true);
select is((select count(*)::int from public.notifications),0,'RLS denies notification history to non-staff');
select throws_ok($$select * from public.claim_notifications(1,60)$$,'42501','staff access required','worker authorization is server controlled');

select * from finish();
rollback;
