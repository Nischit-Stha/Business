begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('34000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','message.staff@example.test','',now(),now(),now()),
('34000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','message.outsider@example.test','',now(),now(),now()),
('34000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','message.inactive@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('34000000-0000-4000-8000-000000000001','Synthetic Messaging Staff','ADMIN');
insert into public.staff_profiles(user_id,full_name,status,is_active) values('34000000-0000-4000-8000-000000000003','Synthetic Inactive Staff','DISABLED',false);
insert into public.customers(id,full_name,phone,email,licence_number,status) values
('44000000-0000-4000-8000-000000000001','Synthetic Message Driver','+61400000101','success@example.test','MSG-1','ACTIVE'),
('44000000-0000-4000-8000-000000000002','Synthetic No Contact',null,null,'MSG-2','ACTIVE'),
('44000000-0000-4000-8000-000000000003','Synthetic Opt Out','+61400000103','optout@example.test','MSG-3','ACTIVE'),
('44000000-0000-4000-8000-000000000004','Synthetic Temporary','+61400000104','temporary@example.test','MSG-4','ACTIVE'),
('44000000-0000-4000-8000-000000000005','Synthetic Permanent','+61400000105','permanent@example.test','MSG-5','ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('54000000-0000-4000-8000-000000000001','MSG001','Synthetic','Messaging',2025,100,'ASSIGNED',100);
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values
('64000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001',now()-interval '30 days',100,'ACTIVE','34000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select public.create_agreement('44000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date-28,current_date+7,current_date-21,100);
select public.transition_agreement((select id from public.agreements),'PENDING_SIGNATURE');
select public.transition_agreement((select id from public.agreements),'ACTIVE');
select lives_ok($$select * from public.run_collection_workflows(current_date)$$,'payment reminder workflow queues deliveries');
select is((select count(*)::integer from public.reminder_actions),(select count(*)::integer from public.message_deliveries where reminder_action_id is not null),'one delivery per reminder action');
select public.run_collection_workflows(current_date);
select is((select count(*)::integer from public.message_deliveries where reminder_action_id is not null),4,'duplicate payment delivery generation prevented');
select is((select count(distinct reminder_action_id)::integer from public.message_deliveries where reminder_action_id is not null),4,'logical payment deliveries are unique');

create temporary table claimed_one as select * from public.claim_message_deliveries(1,60);
select is((select count(*)::integer from claimed_one),1,'fake worker can claim one queued delivery');
select lives_ok($$select public.complete_message_delivery(id,claim_token,'SUCCESS','fake:'||id) from claimed_one$$,'fake success completes');
select is((select status from public.message_deliveries where id=(select id from claimed_one)),'SENT','success marks sent');

reset role;
select app_private.queue_message('temporary-test','44000000-0000-4000-8000-000000000004','PAYMENT_ESCALATION','{"customer_name":"Synthetic Temporary","amount":"10.00"}');
select app_private.queue_message('permanent-test','44000000-0000-4000-8000-000000000005','PAYMENT_ESCALATION','{"customer_name":"Synthetic Permanent","amount":"10.00"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000001',true);
create temporary table claimed_failures as select * from public.claim_message_deliveries(20,60);
select lives_ok($$select public.complete_message_delivery(id,claim_token,'TEMPORARY_FAILURE',null,'FAKE_TEMPORARY','Synthetic temporary') from claimed_failures where logical_key='temporary-test'$$,'retryable failure completes claim');
select is((select status from public.message_deliveries where logical_key='temporary-test'),'RETRY_WAIT','temporary failure waits for retry');
select lives_ok($$select public.complete_message_delivery(id,claim_token,'PERMANENT_FAILURE',null,'FAKE_PERMANENT','Synthetic permanent') from claimed_failures where logical_key='permanent-test'$$,'permanent failure completes claim');
select is((select status from public.message_deliveries where logical_key='permanent-test'),'FAILED','permanent failure stops');

reset role;
select app_private.queue_message('retry-limit','44000000-0000-4000-8000-000000000004','PAYMENT_ESCALATION','{"customer_name":"Synthetic Temporary","amount":"10.00"}');
update public.message_deliveries set max_attempts=1 where logical_key='retry-limit';
set local role authenticated;
select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000001',true);
create temporary table claimed_limit as select * from public.claim_message_deliveries(20,60);
select public.complete_message_delivery(id,claim_token,'TEMPORARY_FAILURE',null,'FAKE_TEMPORARY','Synthetic temporary') from claimed_limit where logical_key='retry-limit';
select is((select status from public.message_deliveries where logical_key='retry-limit'),'FAILED','retry limit produces terminal failure');
select is((select count(*)::integer from public.operational_exceptions where exception_type='MESSAGE_REPEATED_FAILURE' and entity_id=(select id from public.message_deliveries where logical_key='retry-limit')),1,'repeated failure creates one owner exception');

select lives_ok($$select public.set_customer_communication_preferences('44000000-0000-4000-8000-000000000003',false,true,'Synthetic email opt-out')$$,'communication preferences save suppression reason');
reset role;
select app_private.queue_message('optout-test','44000000-0000-4000-8000-000000000003','PAYMENT_ESCALATION','{"customer_name":"Synthetic Opt Out","amount":"10.00"}');
select app_private.queue_message('missing-test','44000000-0000-4000-8000-000000000002','PAYMENT_ESCALATION','{"customer_name":"Synthetic No Contact","amount":"10.00"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000001',true);
select is((select status from public.message_deliveries where logical_key='optout-test'),'SUPPRESSED','email opt-out suppresses delivery');
select is((select status from public.message_deliveries where logical_key='missing-test'),'SUPPRESSED','missing contact suppresses delivery');
select is((select count(*)::integer from public.operational_exceptions where exception_type='MESSAGE_MISSING_CONTACT'),1,'missing contact creates deduplicated exception');

create temporary table concurrency_first as select * from public.claim_message_deliveries(1,60);
create temporary table concurrency_second as select * from public.claim_message_deliveries(100,60);
select is((select count(*)::integer from concurrency_first a join concurrency_second b using(id)),0,'sequential concurrent-worker claims are disjoint');

select public.record_manual_payment((select id from public.agreements),400,now(),'MSG-CLEAR','Synthetic payment clears reminders');
select public.run_collection_workflows(current_date);
select is((select count(*)::integer from public.message_deliveries where agreement_id=(select id from public.agreements) and status in ('QUEUED','RETRY_WAIT','SENDING')),0,'payment clearing cancels pending delivery');

select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.message_deliveries),0,'unauthorized user denied queue reads by RLS');
select throws_ok($$select * from public.claim_message_deliveries(1,60)$$,'42501','staff access required','unauthorized worker claim denied');
select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.generate_message_reminders(current_date)$$,'42501','staff access required','inactive staff denied reminder generation');

select is((select count(*)::integer from public.message_templates),0,'inactive staff denied template reads by RLS');
select * from finish();
rollback;
