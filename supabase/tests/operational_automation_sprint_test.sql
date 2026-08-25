begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('39000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sprint.admin@example.test','',now(),now(),now()),
('39000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sprint.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('39000000-0000-4000-8000-000000000001','Synthetic Sprint Admin','ADMIN');
insert into public.customers(id,full_name,phone,email,licence_number,licence_expiry,status) values
('49000000-0000-4000-8000-000000000001','Synthetic Operational Driver','+61400000901','sprint@example.test','SPRINT-1',current_date+100,'ACTIVE'),
('49000000-0000-4000-8000-000000000002','Synthetic Missing Contact Driver',null,null,'SPRINT-2',current_date+100,'ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('59000000-0000-4000-8000-000000000001','SPR001','Synthetic','Ready',2026,1000,'ASSIGNED',100),
('59000000-0000-4000-8000-000000000002','SPR002','Synthetic','Blocked',2026,2000,'AVAILABLE',100);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) values
('59000000-0000-4000-8000-000000000001','REGISTRATION','VALID',current_date-1,current_date+365,'39000000-0000-4000-8000-000000000001'),
('59000000-0000-4000-8000-000000000001','RWC','VALID',current_date-1,current_date+365,'39000000-0000-4000-8000-000000000001'),
('59000000-0000-4000-8000-000000000002','REGISTRATION','EXPIRED',current_date-365,current_date-1,'39000000-0000-4000-8000-000000000001');
insert into public.customer_approvals(customer_id,status,decided_by,decided_at) values('49000000-0000-4000-8000-000000000001','APPROVED','39000000-0000-4000-8000-000000000001',now()) on conflict(customer_id) do update set status='APPROVED',decided_by=excluded.decided_by,decided_at=excluded.decided_at;
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) values
('49000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date+365,'39000000-0000-4000-8000-000000000001',now()),
('49000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','VERIFIED',current_date+365,'39000000-0000-4000-8000-000000000001',now());
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('69000000-0000-4000-8000-000000000001','49000000-0000-4000-8000-000000000001','59000000-0000-4000-8000-000000000001',now()-interval '10 days',1000,'ACTIVE','39000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','39000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select public.create_agreement('49000000-0000-4000-8000-000000000001','59000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date-1,current_date+21,current_date+1,100);
select public.transition_agreement((select id from public.agreements),'PENDING_SIGNATURE');select public.transition_agreement((select id from public.agreements),'ACTIVE');

select lives_ok($$select public.generate_pre_due_payment_notifications(now())$$,'pre-due generator runs');
select is((select count(*)::integer from public.notifications where dedup_key like 'payment-pre-due:%'),1,'one-day pre-due reminder is generated');
select public.generate_pre_due_payment_notifications(now());
select is((select count(*)::integer from public.notifications where dedup_key like 'payment-pre-due:%'),1,'pre-due reminder is deduplicated');
select lives_ok($$select public.record_manual_payment((select id from public.agreements),25,now(),'SPRINT-PAYMENT','Synthetic receipt')$$,'payment posts successfully');
select is((select count(*)::integer from public.notifications where type='PAYMENT_RECEIVED'),1,'payment received notification queues automatically');
select public.record_manual_payment((select id from public.agreements),25,now(),'SPRINT-PAYMENT-2','Synthetic second receipt');
select is((select count(*)::integer from public.notifications where type='PAYMENT_RECEIVED'),2,'each distinct payment gets one notification');

create temporary table sprint_claim as select * from public.claim_notifications(1,60);
select lives_ok($$select public.complete_notification(id,claim_token,'SUCCESS','local-sprint',null,null,5,'LOCAL_SYNTHETIC') from sprint_claim$$,'provider-neutral completion records attempt');
select is((select count(*)::integer from public.notification_delivery_attempts),1,'delivery attempt is durable');
reset role;
select throws_ok($$update public.notification_delivery_attempts set provider='changed'$$,'P0001','operational execution history is immutable','delivery attempts are immutable');
set local role authenticated;select set_config('request.jwt.claim.sub','39000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.record_notification_delivery_receipt((select id from sprint_claim),'local-sprint')$$,'safe internal receipt marks delivered');
select is((select status from public.notifications where id=(select id from sprint_claim)),'DELIVERED','SENT transitions to DELIVERED');

reset role;
select app_private.queue_notification('missing-contact-important','LICENCE_EXPIRED','49000000-0000-4000-8000-000000000002','{"customer_first_name":"Synthetic","due_date":"today"}',now(),'39000000-0000-4000-8000-000000000001');
set local role authenticated;select set_config('request.jwt.claim.sub','39000000-0000-4000-8000-000000000001',true);
select public.refresh_notification_attention();
select is((select count(*)::integer from public.operational_exceptions where exception_type='MISSING_IMPORTANT_CUSTOMER_CONTACT'),1,'important missing contact creates one exception');
select public.refresh_notification_attention();
select is((select count(*)::integer from public.operational_exceptions where exception_type='MISSING_IMPORTANT_CUSTOMER_CONTACT'),1,'missing contact attention is deduplicated');

select public.update_notification_settings('{0,1,3,7}','{1}','{24,0}','{24,0}','{30,14,7,0}',3,true);
select public.create_vehicle_issue('59000000-0000-4000-8000-000000000001','49000000-0000-4000-8000-000000000001',(select id from public.agreements),'LOW','OTHER','Synthetic safe issue',null);
select public.assign_vehicle_issue((select id from public.vehicle_issues),'39000000-0000-4000-8000-000000000001');
select public.update_vehicle_issue_status((select id from public.vehicle_issues),'IN_PROGRESS','Internal note must not be sent');
select is((select count(*)::integer from public.notifications where type='ISSUE_STATUS_UPDATE'),1,'configured issue transition queues customer-safe notification');
select ok((select rendered_message not like '%Internal note%' from public.notifications where type='ISSUE_STATUS_UPDATE'),'issue notification excludes internal note');

select lives_ok($$select public.run_scheduled_job('REFRESH_TOLL_FINE_ATTENTION','MANUAL','sprint-job-1')$$,'known job runs safely');
select is((select status from public.scheduled_job_executions where idempotency_key='sprint-job-1'),'SUCCEEDED','execution history records success');
select is((select count(*)::integer from public.scheduled_job_executions where idempotency_key='sprint-job-1'),1,'idempotency key creates one execution');
select lives_ok($$select public.run_scheduled_job('REFRESH_TOLL_FINE_ATTENTION','MANUAL','sprint-job-1')$$,'replayed idempotency key returns existing execution');
reset role;
select throws_ok($$update public.scheduled_job_executions set result_summary='{"changed":true}' where idempotency_key='sprint-job-1'$$,'P0001','completed job execution history is immutable','completed execution is immutable');
update public.scheduled_jobs set next_run_at=now()+interval '1 day';
update public.scheduled_jobs set next_run_at=now()-interval '1 minute' where job_key in ('REFRESH_TOLL_FINE_ATTENTION','REFRESH_NOTIFICATION_ATTENTION');
set local role authenticated;select set_config('request.jwt.claim.sub','39000000-0000-4000-8000-000000000001',true);
select is((select count(*)::integer from public.run_due_scheduled_jobs(8)),2,'due runner selects bounded due jobs');
select is((select count(*)::integer from public.scheduled_jobs where lock_token is not null),0,'job locks release after execution');
reset role;delete from public.notification_settings;update public.scheduled_jobs set next_run_at=now()+interval '1 day';update public.scheduled_jobs set next_run_at=now()-interval '2 minutes' where job_key in ('GENERATE_NOTIFICATIONS','REFRESH_OWNER');
set local role authenticated;select set_config('request.jwt.claim.sub','39000000-0000-4000-8000-000000000001',true);
select is((select count(*)::integer from public.run_due_scheduled_jobs(8)),2,'due runner isolates job execution outcomes');
select is((select last_status from public.scheduled_jobs where job_key='GENERATE_NOTIFICATIONS'),'FAILED','one job failure is recorded safely');
select is((select last_status from public.scheduled_jobs where job_key='REFRESH_OWNER'),'SUCCEEDED','failed job does not block unrelated job');

select is((select full_name from public.customer_operational_summary where customer_id='49000000-0000-4000-8000-000000000001'),'Synthetic Operational Driver','customer summary is accurate');
select hasnt_column('public','customer_operational_summary','phone','customer summary excludes phone');
select hasnt_column('public','customer_operational_summary','email','customer summary excludes email');
select ok((select readiness from public.vehicle_operational_detail where vehicle_id='59000000-0000-4000-8000-000000000001') is false,'assigned vehicle is not advertised as allocatable');
select ok((select blockers ? 'Registration is not valid' from public.movement_readiness where vehicle_id='59000000-0000-4000-8000-000000000002'),'movement readiness explains expired registration');
select is((select queue_group from public.issue_work_queue where id=(select id from public.vehicle_issues)),'ASSIGNED_TO_ME','issue queue is staff identity-aware');

select set_config('request.jwt.claim.sub','39000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.customer_operational_summary),0,'read models deny non-staff through underlying RLS');
select throws_ok($$select public.run_scheduled_job('REFRESH_OWNER')$$,'42501','staff access required','scheduler mutation requires active staff');

select * from finish();
rollback;
