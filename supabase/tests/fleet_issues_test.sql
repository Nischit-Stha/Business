begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('34000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','issues.staff@example.test','',now(),now(),now()),
('34000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','issues.assignee@example.test','',now(),now(),now()),
('34000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','issues.outsider@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values
('34000000-0000-4000-8000-000000000001','Synthetic Issue Admin','ADMIN'),
('34000000-0000-4000-8000-000000000002','Synthetic Issue Staff','STAFF');
insert into public.customers(id,full_name,licence_number,status) values('44000000-0000-4000-8000-000000000001','Synthetic Fleet Customer','ISSUE-1','ACTIVE');
update public.customer_approvals set status='APPROVED',decided_by='34000000-0000-4000-8000-000000000001',decided_at=now() where customer_id='44000000-0000-4000-8000-000000000001';
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) values
('44000000-0000-4000-8000-000000000001','DRIVER_LICENCE','VERIFIED',current_date+365,'34000000-0000-4000-8000-000000000001',now()),
('44000000-0000-4000-8000-000000000001','PROOF_OF_ADDRESS','VERIFIED',null,'34000000-0000-4000-8000-000000000001',now());
insert into public.vehicles(id,registration,make,model,year,odometer,operational_status,weekly_rate) values
('54000000-0000-4000-8000-000000000001','ISS001','Synthetic','Assigned',2026,1000,'ASSIGNED',100),
('54000000-0000-4000-8000-000000000002','ISS002','Synthetic','Pickup',2026,2000,'AVAILABLE',100);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) select v.id,t,'VALID',current_date-1,current_date+365,'34000000-0000-4000-8000-000000000001' from public.vehicles v cross join (values('REGISTRATION'),('RWC')) x(t) where v.id in ('54000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000002');
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('74000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001',now()-interval '7 days',1000,'ACTIVE','34000000-0000-4000-8000-000000000001');
insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,end_date,first_due_date,weekly_amount,created_by) values
('64000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001','WEEKLY_RENTAL','ACTIVE',current_date-7,current_date+7,current_date-7,100,'34000000-0000-4000-8000-000000000001'),
('64000000-0000-4000-8000-000000000002','44000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000002','WEEKLY_RENTAL','ACTIVE',current_date,current_date+7,current_date,100,'34000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

select lives_ok($$select public.create_vehicle_issue('54000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','HIGH','BREAKDOWN','Synthetic breakdown',null)$$,'staff can create an issue');
select is((select status from public.vehicle_issues where description='Synthetic breakdown'),'OPEN','new unassigned issue is open');
select is((select operational_status from public.vehicles where id='54000000-0000-4000-8000-000000000001'),'OFF_ROAD','blocking issue moves vehicle off-road');
select isnt((select ready_for_allocation from public.fleet_operations where id='54000000-0000-4000-8000-000000000001'),true,'blocking issue prevents allocation readiness');
select lives_ok($$select public.assign_vehicle_issue((select id from public.vehicle_issues where description='Synthetic breakdown'),'34000000-0000-4000-8000-000000000002')$$,'issue can be assigned');
select is((select status from public.vehicle_issues where description='Synthetic breakdown'),'ASSIGNED','assignment advances open issue state');
select lives_ok($$select public.update_vehicle_issue_status((select id from public.vehicle_issues where description='Synthetic breakdown'),'IN_PROGRESS','Synthetic technician dispatched')$$,'issue status can advance');
select lives_ok($$select public.add_vehicle_issue_note((select id from public.vehicle_issues where description='Synthetic breakdown'),'Synthetic diagnostic note')$$,'issue note can be added');
select is((select count(*)::integer from public.vehicle_issue_events where vehicle_issue_id=(select id from public.vehicle_issues where description='Synthetic breakdown')),4,'full immutable issue history is retained');
select ok((public.owner_operations_dashboard()->'attention') @> jsonb_build_array(jsonb_build_object('type','VEHICLE_ISSUE')),'high issue appears on owner dashboard');
select ok((select href like '/operations/issues/%' from jsonb_to_recordset(public.owner_operations_dashboard()->'attention') as x(type text,href text) where type='VEHICLE_ISSUE'),'owner issue links directly to issue');
select lives_ok($$select public.resolve_vehicle_issue((select id from public.vehicle_issues where description='Synthetic breakdown'),'Synthetic battery replaced')$$,'issue can be resolved');
select is((select status from public.vehicle_issues where description='Synthetic breakdown'),'RESOLVED','resolution closes issue');
select is((select operational_status from public.vehicles where id='54000000-0000-4000-8000-000000000001'),'ASSIGNED','resolution restores assigned vehicle state');
select isnt((public.owner_operations_dashboard()->'attention') @> jsonb_build_array(jsonb_build_object('type','VEHICLE_ISSUE')),true,'resolved issue leaves owner attention');

select lives_ok($$select public.schedule_pickup('64000000-0000-4000-8000-000000000002',now()+interval '2 hours','Synthetic pickup notes')$$,'pickup can be explicitly scheduled');
select ok((select scheduled_at is not null and staff_notes='Synthetic pickup notes' from public.pickup_checklists where agreement_id='64000000-0000-4000-8000-000000000002'),'pickup schedule and notes persist');
select is((select operational_status from public.vehicles where id='54000000-0000-4000-8000-000000000002'),'PICKUP_PENDING','scheduled pickup marks movement pending');
select lives_ok($$select public.create_vehicle_issue('54000000-0000-4000-8000-000000000002','44000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002','HIGH','TYRE','Synthetic blocking tyre issue',null)$$,'blocking pickup issue can be recorded');
select throws_ok($$select public.complete_pickup((select id from public.pickup_checklists where agreement_id='64000000-0000-4000-8000-000000000002'),2000)$$,'P0001','vehicle has an unresolved blocking issue','blocking issue prevents pickup completion');
select lives_ok($$select public.resolve_vehicle_issue((select id from public.vehicle_issues where description='Synthetic blocking tyre issue'),'Synthetic tyre replaced')$$,'pickup blocker can be resolved');
select lives_ok($$select public.complete_pickup((select id from public.pickup_checklists where agreement_id='64000000-0000-4000-8000-000000000002'),2000)$$,'pickup completes after blocker resolution');
select ok((select status='COMPLETED' and actual_at is not null from public.pickup_checklists where agreement_id='64000000-0000-4000-8000-000000000002'),'pickup actual time is retained');
select lives_ok($$select public.schedule_return('74000000-0000-4000-8000-000000000001',now()+interval '1 day','Synthetic return notes')$$,'return can be explicitly scheduled');
select ok((select scheduled_at is not null and staff_notes='Synthetic return notes' from public.return_checklists where assignment_id='74000000-0000-4000-8000-000000000001'),'return schedule and notes persist');
select is((select operational_status from public.vehicles where id='54000000-0000-4000-8000-000000000001'),'RETURN_PENDING','scheduled return marks movement pending');

select set_config('request.jwt.claim.sub','34000000-0000-4000-8000-000000000003',true);
select is((select count(*)::integer from public.vehicle_issues),0,'non-staff cannot read issues');
select throws_ok($$select public.create_vehicle_issue('54000000-0000-4000-8000-000000000001',null,null,'LOW','OTHER','Unauthorized issue',null)$$,'42501','staff access required','non-staff cannot create issues');
select throws_ok($$select public.schedule_return('74000000-0000-4000-8000-000000000001',now(),null)$$,'42501','staff access required','non-staff cannot schedule movements');

select * from finish();
rollback;
