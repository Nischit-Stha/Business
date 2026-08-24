begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('37000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','docs.admin@example.test','',now(),now(),now()),
('37000000-0000-4000-8000-000000000002','00000000-0000-0000-8000-000000000000','authenticated','authenticated','docs.staff@example.test','',now(),now(),now()),
('37000000-0000-4000-8000-000000000003','00000000-0000-0000-8000-000000000000','authenticated','authenticated','docs.inactive@example.test','',now(),now(),now()),
('37000000-0000-4000-8000-000000000004','00000000-0000-0000-8000-000000000000','authenticated','authenticated','docs.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role,status,is_active) values
('37000000-0000-4000-8000-000000000001','Synthetic Document Admin','ADMIN','ACTIVE',true),
('37000000-0000-4000-8000-000000000002','Synthetic Document Staff','STAFF','ACTIVE',true),
('37000000-0000-4000-8000-000000000003','Synthetic Inactive Staff','STAFF','DISABLED',false);
insert into public.customers(id,full_name,licence_number,status) values('47000000-0000-4000-8000-000000000001','Synthetic Document Customer','DOC-1','ACTIVE');
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values('57000000-0000-4000-8000-000000000001','DOC001','Synthetic','Doc',2025,1,'AVAILABLE',100);

select is((select count(*)::integer from storage.buckets where id in ('customer-documents','vehicle-compliance-documents') and public),0,'document buckets are not public');
select is((select count(*)::integer from pg_policies where schemaname='storage' and tablename='objects' and policyname like '%private_documents%'),0,'no authenticated document object policy exists');

set local role authenticated; select set_config('request.jwt.claim.role','authenticated',true); select set_config('request.jwt.claim.sub','37000000-0000-4000-8000-000000000002',true);
select ok(not has_function_privilege('authenticated','public.register_document_upload(uuid,uuid,text,text,text,text,text,bigint,text,date)','execute'),'browser role cannot register upload metadata');
set local role service_role;
select lives_ok($$select public.register_document_upload('37000000-0000-4000-8000-000000000002','47000000-0000-4000-8000-000000000001','DRIVER_LICENCE','customer-documents','customers/47000000-0000-4000-8000-000000000001/driver_licence/10000000-0000-4000-8000-000000000001.pdf','licence.pdf','application/pdf',100,repeat('a',64),current_date+365)$$,'authorized upload metadata is created');
set local role postgres;
select is((select uploaded_by from public.document_versions limit 1),'37000000-0000-4000-8000-000000000002'::uuid,'uploader attribution recorded');
select throws_ok($$select public.register_document_upload('37000000-0000-4000-8000-000000000002','47000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','customer-documents','customers/47000000-0000-4000-8000-000000000001/proof_of_address/10000000-0000-4000-8000-000000000002.exe','bad.exe','application/x-msdownload',100,repeat('b',64),null)$$,'22023','unsupported file type','unsupported file type rejected');
select throws_ok($$select public.register_document_upload('37000000-0000-4000-8000-000000000002','47000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','customer-documents','customers/47000000-0000-4000-8000-000000000001/proof_of_address/10000000-0000-4000-8000-000000000002.pdf','large.pdf','application/pdf',10485761,repeat('b',64),null)$$,'22023','file size exceeds 10 MiB limit','oversized file rejected');
select throws_ok($$select public.register_document_upload('37000000-0000-4000-8000-000000000002','47000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','customer-documents','../escape.pdf','escape.pdf','application/pdf',100,repeat('b',64),null)$$,'22023','invalid object metadata','path traversal rejected');
select throws_ok($$select public.register_document_upload('37000000-0000-4000-8000-000000000004','47000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','customer-documents','customers/47000000-0000-4000-8000-000000000001/proof_of_address/10000000-0000-4000-8000-000000000004.pdf','address.pdf','application/pdf',100,repeat('d',64),null)$$,'42501','staff access required','unauthorized actor upload denied');
select public.register_document_upload('37000000-0000-4000-8000-000000000002','47000000-0000-4000-8000-000000000001','DRIVER_LICENCE','customer-documents','customers/47000000-0000-4000-8000-000000000001/driver_licence/10000000-0000-4000-8000-000000000003.pdf','replacement.pdf','application/pdf',110,repeat('c',64),current_date+400);
select is((select count(*)::integer from public.document_versions where document_type='DRIVER_LICENCE'),2,'replacement preserves both versions');
select is((select count(*)::integer from public.document_versions where document_type='DRIVER_LICENCE' and status='SUPERSEDED'),1,'prior version marked superseded');
set local role authenticated; select set_config('request.jwt.claim.sub','37000000-0000-4000-8000-000000000002',true);
select public.decide_document_version((select id from public.document_versions where status='SUBMITTED' and document_type='DRIVER_LICENCE'),'VERIFIED',current_date+400,null);
select is((select status from public.customer_documents where document_type='DRIVER_LICENCE'),'VERIFIED','verification updates active readiness metadata');
select is((select count(*)::integer from public.document_access_events where action in ('UPLOAD','SUPERSEDE','VERIFY')),4,'upload supersede and verify access events recorded');
select public.record_document_view((select id from public.document_versions where status='VERIFIED'),'{}');
select is((select count(*)::integer from public.document_access_events where action='VIEW_LINK_GENERATED'),1,'view link request recorded');
select set_config('request.jwt.claim.sub','37000000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.record_document_view((select id from public.document_versions limit 1),'{}')$$,'42501','staff access required','unauthorized signed URL authorization denied');
select set_config('request.jwt.claim.sub','37000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.record_document_view('10000000-0000-4000-8000-000000000003','{}')$$,'42501','staff access required','inactive staff denied');
select set_config('request.jwt.claim.sub','37000000-0000-4000-8000-000000000001',true);
select public.decide_customer_approval('47000000-0000-4000-8000-000000000001','APPROVED');
select set_config('request.jwt.claim.sub','37000000-0000-4000-8000-000000000002',true);
select public.set_customer_document('47000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','VERIFIED',null);
select public.set_customer_document('47000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date-1);
select is((select ready from public.customer_readiness where customer_id='47000000-0000-4000-8000-000000000001'),false,'expired uploaded licence blocks readiness');
select public.set_vehicle_compliance('57000000-0000-4000-8000-000000000001','REGISTRATION','EXPIRED',current_date-30,current_date-1);
select public.set_vehicle_compliance('57000000-0000-4000-8000-000000000001','RWC','EXPIRED',current_date-30,current_date-1);
set local role postgres;
select is(app_private.vehicle_is_compliant('57000000-0000-4000-8000-000000000001'),false,'expired registration and RWC block pickup');
select ok((select count(*)=2 from storage.buckets where id in ('customer-documents','vehicle-compliance-documents') and not public),'both buckets remain private');
select * from finish(); rollback;
