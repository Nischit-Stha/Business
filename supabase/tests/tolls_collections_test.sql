begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('33000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','collections.staff@example.test','',now(),now(),now()),
('33000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','collections.outsider@example.test','',now(),now(),now()),
('33000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','collections.inactive@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('33000000-0000-4000-8000-000000000001','Synthetic Collections Staff','ADMIN');
insert into public.staff_profiles(user_id,full_name,status,is_active) values('33000000-0000-4000-8000-000000000003','Synthetic Inactive Staff','DISABLED',false);
insert into public.customers(id,full_name,licence_number,status) values
('43000000-0000-4000-8000-000000000001','Synthetic Exact Driver','COLL-1','ACTIVE'),
('43000000-0000-4000-8000-000000000002','Synthetic Other Driver','COLL-2','ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('53000000-0000-4000-8000-000000000001','COL001','Synthetic','Exact',2025,100,'ASSIGNED',100),
('53000000-0000-4000-8000-000000000002','COL002','Synthetic','Never assigned',2025,100,'AVAILABLE',100),
('53000000-0000-4000-8000-000000000003','COL003','Synthetic','Corrupt overlap',2025,100,'ASSIGNED',100);
insert into public.customer_approvals(customer_id,status,decided_by,decided_at) select id,'APPROVED','33000000-0000-4000-8000-000000000001',now() from public.customers on conflict(customer_id) do update set status='APPROVED',decided_by=excluded.decided_by,decided_at=excluded.decided_at;
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) select c.id,t,'VERIFIED',current_date+365,'33000000-0000-4000-8000-000000000001',now() from public.customers c cross join (values('DRIVER_LICENCE'),('PROOF_OF_ADDRESS')) d(t);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) select v.id,t,'VALID',current_date-1,current_date+365,'33000000-0000-4000-8000-000000000001' from public.vehicles v cross join (values('REGISTRATION'),('RWC')) x(t);
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,returned_at,pickup_odometer,return_odometer,assignment_status,created_by) values
('63000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',now()-interval '30 days',null,100,null,'ACTIVE','33000000-0000-4000-8000-000000000001');
-- Simulate legacy-corrupt overlapping custody to verify defensive ambiguity handling.
alter table public.vehicle_assignments drop constraint vehicle_assignments_no_overlap;
drop index public.vehicle_assignments_one_active_vehicle;
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,returned_at,pickup_odometer,return_odometer,assignment_status,created_by) values
('63000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000003',now()-interval '20 days',null,100,null,'ACTIVE','33000000-0000-4000-8000-000000000001'),
('63000000-0000-4000-8000-000000000003','43000000-0000-4000-8000-000000000002','53000000-0000-4000-8000-000000000003',now()-interval '10 days',null,100,null,'ACTIVE','33000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

select lives_ok($$select public.create_toll_fine_notice('TOLL','EXACT-1','53000000-0000-4000-8000-000000000001','COL001',now()-interval '5 days',now()-interval '4 days',12.50,'SYNTHETIC')$$,'exact notice is created and matched');
select is((select status from public.toll_fine_notices where external_reference='EXACT-1'),'MATCHED','exact single assignment is deterministic');
select is((select matched_customer_id from public.notice_match_results where notice_id=(select id from public.toll_fine_notices where external_reference='EXACT-1')),'43000000-0000-4000-8000-000000000001'::uuid,'exact match returns customer');
select lives_ok($$select public.create_toll_fine_notice('PARKING_FINE','NONE-1','53000000-0000-4000-8000-000000000002','COL002',now()-interval '5 days',now()-interval '4 days',100,'SYNTHETIC')$$,'no-match notice is accepted for review');
select is((select status from public.toll_fine_notices where external_reference='NONE-1'),'NEEDS_REVIEW','no match requires review');
select lives_ok($$select public.create_toll_fine_notice('TOLL','AMBIG-1','53000000-0000-4000-8000-000000000003','COL003',now()-interval '5 days',now()-interval '4 days',20,'SYNTHETIC')$$,'ambiguous notice is accepted for review');
select ok((select status='NEEDS_REVIEW' from public.toll_fine_notices where external_reference='AMBIG-1') and (select candidate_count=2 from public.notice_match_results where notice_id=(select id from public.toll_fine_notices where external_reference='AMBIG-1')),'ambiguous match is not silently assigned');
select throws_ok($$select public.review_notice_allocation((select id from public.toll_fine_notices where external_reference='AMBIG-1'),'CONFIRMED','43000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000002','Not allowed')$$,'P0001','confirmation must use high-confidence automated match','ambiguous suggestion cannot be confirmed');
select throws_ok($$select public.review_notice_allocation((select id from public.toll_fine_notices where external_reference='AMBIG-1'),'MANUALLY_ASSIGNED','43000000-0000-4000-8000-000000000002','63000000-0000-4000-8000-000000000003','')$$,'22023','override reason required','override reason is mandatory');
select lives_ok($$select public.review_notice_allocation((select id from public.toll_fine_notices where external_reference='AMBIG-1'),'MANUALLY_ASSIGNED','43000000-0000-4000-8000-000000000002','63000000-0000-4000-8000-000000000003','Reviewed custody evidence')$$,'manual allocation with reason succeeds');
select ok((select match_status='AMBIGUOUS' from public.notice_match_results where notice_id=(select id from public.toll_fine_notices where external_reference='AMBIG-1')) and (select automated_match_result_id is not null from public.notice_allocations where notice_id=(select id from public.toll_fine_notices where external_reference='AMBIG-1')),'manual override preserves automated result');
select lives_ok($$select public.transition_toll_fine_notice((select id from public.toll_fine_notices where external_reference='AMBIG-1'),'DISPUTED','Synthetic dispute')$$,'confirmed notice can be disputed');
select lives_ok($$select public.refresh_toll_fine_owner_attention()$$,'owner attention refresh runs');
select is((select status from public.operational_exceptions where entity_id=(select id from public.toll_fine_notices where external_reference='AMBIG-1') and exception_type='DISPUTED_NOTICE'),'OPEN','dispute creates deduplicated owner attention');
select lives_ok($$select public.transition_toll_fine_notice((select id from public.toll_fine_notices where external_reference='AMBIG-1'),'CANCELLED','Dispute resolved externally')$$,'disputed notice can be cancelled');
select lives_ok($$select public.refresh_toll_fine_owner_attention()$$,'owner attention refresh clears resolved lifecycle items');
select is((select status from public.operational_exceptions where entity_id=(select id from public.toll_fine_notices where external_reference='AMBIG-1') and exception_type='DISPUTED_NOTICE'),'RESOLVED','owner attention resolves when dispute closes');
select is((select count(*)::integer from public.vehicle_assignments),3,'notice allocation does not alter assignment history');
select lives_ok($$select public.review_notice_allocation((select id from public.toll_fine_notices where external_reference='EXACT-1'),'CONFIRMED','43000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001','Confirmed against custody history')$$,'exact driver is confirmed');
select lives_ok($$select public.transition_toll_fine_notice((select id from public.toll_fine_notices where external_reference='EXACT-1'),'TRANSFER_PENDING','Synthetic transfer preparation')$$,'notice can become transfer pending');
select lives_ok($$select public.transition_toll_fine_notice((select id from public.toll_fine_notices where external_reference='EXACT-1'),'TRANSFERRED','Synthetic external completion')$$,'notice can be marked transferred');
select is((select count(*)::integer from public.notice_status_history where notice_id=(select id from public.toll_fine_notices where external_reference='EXACT-1')),3,'resolution lifecycle history is retained');
select ok((select transferred_at is not null from public.toll_fine_notices where external_reference='EXACT-1'),'transferred timestamp is recorded');
reset role;
select throws_ok($$update public.notice_match_results set reason='mutated' where notice_id=(select id from public.toll_fine_notices where external_reference='EXACT-1')$$,'P0001','historical toll/fine evidence is immutable','historical evidence cannot be mutated');
set local role authenticated;
select throws_ok($$select public.create_toll_fine_notice('TOLL','EXACT-1','53000000-0000-4000-8000-000000000001','COL001',now(),now(),1,'SYNTHETIC')$$,'23505',null,'duplicate external reference is rejected');
select is((select match_confidence from public.toll_fine_notices where external_reference='EXACT-1'),'HIGH','clear custody receives high confidence');

select public.create_agreement('43000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date-28,current_date+7,current_date-21,100);
select public.transition_agreement((select id from public.agreements),'PENDING_SIGNATURE'); select public.transition_agreement((select id from public.agreements),'ACTIVE');
select lives_ok($$select * from public.run_collection_workflows(current_date)$$,'reminder workflow runs');
select is((select count(*)::integer from public.reminder_actions),4,'all due cadence stages queue once');
select public.run_collection_workflows(current_date);
select is((select count(*)::integer from public.reminder_actions),4,'reminder generation is idempotent');
select lives_ok($$select public.create_payment_promise((select id from public.agreements),200,current_date,'Synthetic promise')$$,'promise-to-pay can be created');
select is((select status from public.payment_promises),'ACTIVE','promise starts active');
select public.run_collection_workflows(current_date+1);
select is((select status from public.payment_promises),'BROKEN','past unpaid promise is marked broken');
select public.run_collection_workflows(current_date+2); select public.run_collection_workflows(current_date+3);
select is((select count(*)::integer from public.operational_exceptions where exception_type='BROKEN_PAYMENT_PROMISE'),1,'broken-promise exception is deduplicated');
select public.record_manual_payment((select id from public.agreements),400,now(),'CLEAR-1','Synthetic clearing payment');
select public.run_collection_workflows(current_date);
select is((select count(*)::integer from public.reminder_actions where status='QUEUED'),0,'queued reminders stop when arrears clear');

select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.toll_fine_notices),0,'unauthorized access is denied by RLS');
select throws_ok($$select public.create_toll_fine_notice('TOLL',null,'53000000-0000-4000-8000-000000000001','COL001',now(),now(),1,'SYNTHETIC')$$,'42501','staff access required','unauthorized notice mutation denied');
select set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000003',true);
select throws_ok($$select * from public.run_collection_workflows(current_date)$$,'42501','staff access required','inactive staff denied');

select * from finish();
rollback;
