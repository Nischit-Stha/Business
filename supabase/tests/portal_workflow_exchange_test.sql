begin;
create extension if not exists pgtap with schema extensions;
select plan(17);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('3a000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','exchange.staff@example.test','',now(),now(),now()),
('3a000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','exchange.a@example.test','',now(),now(),now()),
('3a000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','exchange.b@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('3a000000-0000-4000-8000-000000000001','Synthetic Exchange Staff','ADMIN');
insert into public.customers(id,full_name,email,licence_number,status) values('4a000000-0000-4000-8000-000000000001','Synthetic Exchange A','exchange.a@example.test','EX-A','ACTIVE'),('4a000000-0000-4000-8000-000000000002','Synthetic Exchange B','exchange.b@example.test','EX-B','ACTIVE');
insert into public.customer_portal_accounts(user_id,customer_id,created_by) values('3a000000-0000-4000-8000-000000000002','4a000000-0000-4000-8000-000000000001','3a000000-0000-4000-8000-000000000001'),('3a000000-0000-4000-8000-000000000003','4a000000-0000-4000-8000-000000000002','3a000000-0000-4000-8000-000000000001');
set local role authenticated; select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.submit_portal_request('GENERAL_REQUEST','Synthetic help request',null,null)$$,'customer submits request');
select is((select status from public.portal_requests),'SUBMITTED','request starts submitted');
select hasnt_column('public','portal_requests','resolution_reason','internal resolution hidden');
select hasnt_column('public','portal_requests','assigned_staff_id','staff identity hidden');
select throws_ok($$select public.decide_portal_request((select id from public.portal_requests),'APPROVED','unsafe',null)$$,'42501','staff access required','customer cannot approve request');
reset role;
set local role authenticated;select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.assign_portal_request((select id from public.customer_portal_requests),'3a000000-0000-4000-8000-000000000001')$$,'staff assigns request');
select is((select status from public.customer_portal_requests),'IN_REVIEW','assignment moves request into review');
select lives_ok($$select public.decide_portal_request((select id from public.customer_portal_requests),'APPROVED','We can help with this.',null)$$,'staff approves request');
select lives_ok($$select public.complete_portal_request((select id from public.customer_portal_requests),'Completed safely.')$$,'staff completes approved request');
select is((select count(*)::int from public.notifications where type in ('PORTAL_REQUEST_RECEIVED','PORTAL_REQUEST_APPROVED')),2,'request notifications generated');
reset role;set local role service_role;
select lives_ok($$select public.register_portal_document_upload('3a000000-0000-4000-8000-000000000002','DRIVER_LICENCE','customer-documents','customers/4a000000-0000-4000-8000-000000000001/driver_licence/1a000000-0000-4000-8000-000000000001.pdf','licence.pdf','application/pdf',100,repeat('a',64),current_date+100)$$,'portal upload registered');
select throws_ok($$select public.register_portal_document_upload('3a000000-0000-4000-8000-000000000002','DRIVER_LICENCE','customer-documents','customers/4a000000-0000-4000-8000-000000000002/driver_licence/1a000000-0000-4000-8000-000000000002.pdf','licence.pdf','application/pdf',100,repeat('b',64),current_date+100)$$,'22023','invalid object path','customer cannot choose another path');
reset role;set local role authenticated;select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.authorize_customer_document_access((select id from public.document_versions))$$,'42501','approved document not found','pending document cannot be downloaded');
select throws_ok($$select public.review_portal_document((select id from public.document_versions),'VERIFIED',null)$$,'42501','staff access required','customer cannot verify document');
select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.review_portal_document((select id from public.document_versions),'VERIFIED',null)$$,'staff verifies document');
select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.authorize_customer_document_access((select id from public.document_versions))$$,'42501','approved document not found','customer B cannot access customer A document');
select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000002',true);
select lives_ok($$select * from public.authorize_customer_document_access((select id from public.portal_documents))$$,'owner receives authorized access metadata');
select * from finish();rollback;
