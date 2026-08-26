begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('31000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','agreement.staff@example.test','',now(),now(),now()),
  ('31000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','agreement.outsider@example.test','',now(),now(),now()),
  ('31000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','agreement.disabled@example.test','',now(),now(),now());
insert into public.staff_profiles (user_id, full_name) values
  ('31000000-0000-4000-8000-000000000001','Agreement Test Staff');
insert into public.staff_profiles (user_id, full_name, status, is_active) values
  ('31000000-0000-4000-8000-000000000003','Disabled Agreement Staff','DISABLED',false);
insert into public.customers (id, full_name, licence_number, status) values
  ('41000000-0000-4000-8000-000000000001','Agreement Test Customer','AGR-TEST-1','ACTIVE');
insert into public.vehicles (id, registration, make, model, year, odometer, operational_status, weekly_rate) values
  ('51000000-0000-4000-8000-000000000001','AGR001','Synthetic','Agreement Car',2025,100,'AVAILABLE',100),
  ('51000000-0000-4000-8000-000000000002','AGR002','Synthetic','Open Car',2025,100,'AVAILABLE',125);

insert into public.customer_approvals(customer_id,status,decided_by,decided_at) select id,'APPROVED','31000000-0000-4000-8000-000000000001',now() from public.customers on conflict(customer_id) do update set status='APPROVED',decided_by=excluded.decided_by,decided_at=excluded.decided_at;
insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) select c.id,t,'VERIFIED',current_date+365,'31000000-0000-4000-8000-000000000001',now() from public.customers c cross join (values('DRIVER_LICENCE'),('PROOF_OF_ADDRESS')) d(t);
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) select v.id,t,'VALID',current_date-1,current_date+365,'31000000-0000-4000-8000-000000000001' from public.vehicles v cross join (values('REGISTRATION'),('RWC')) x(t);
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

set local role postgres;
insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('41000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001',now()-interval '30 days',100,'ACTIVE','31000000-0000-4000-8000-000000000001');
update public.vehicles set operational_status='ASSIGNED' where id='51000000-0000-4000-8000-000000000001';
set local role authenticated;select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
select lives_ok(
  format($sql$select public.create_agreement('41000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',%L,%L,%L,100,0,null,null,null,null)$sql$,
    current_date - 14, current_date + 21, current_date - 14),
  'staff can create an agreement'
);
select is((select status from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000001'),'DRAFT','agreement starts in draft');
select lives_ok(format($sql$select public.transition_agreement((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000001'),'PENDING_SIGNATURE')$sql$),'draft can await signature');
select lives_ok(format($sql$select public.transition_agreement((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000001'),'ACTIVE')$sql$),'agreement activates with matching assignment');
select is((select count(*)::integer from public.payment_schedule_items),6,'activation generates weekly schedule through end date');
select is((select max(due_date) from public.payment_schedule_items),current_date + 21,'schedule respects agreement end date');
select is(public.generate_payment_schedule((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000001'),current_date + 21),0,'schedule generation is idempotent');
select is((select overdue_amount from public.agreement_payment_summary where agreement_id=(select id from public.agreements where status='ACTIVE')),200::numeric,'overdue calculation totals past unpaid obligations');

select public.create_agreement('41000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001','WEEKLY_RENTAL',current_date,current_date + 7,current_date,100);
select public.transition_agreement((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000001' and status='DRAFT'),'PENDING_SIGNATURE');
select throws_ok(
  $$select public.transition_agreement((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000001' and status='PENDING_SIGNATURE'),'ACTIVE')$$,
  'P0001','vehicle already has an active agreement','conflicting active agreement is prevented'
);

select lives_ok(
  $$select public.record_manual_payment((select id from public.agreements where status='ACTIVE'),100,now() - interval '1 hour','PAYID-EXACT','Synthetic exact payment')$$,
  'exact payment records'
);
select is((select amount_paid from public.payment_schedule_items where sequence_number=1),100::numeric,'exact payment pays one obligation');
select lives_ok(
  $$select public.record_manual_payment((select id from public.agreements where status='ACTIVE'),40,now() - interval '50 minutes','PAYID-PART','Synthetic partial')$$,
  'partial payment records'
);
select is((select amount_paid from public.payment_schedule_items where sequence_number=2),40::numeric,'partial payment updates oldest unpaid obligation');
select lives_ok(
  $$select public.record_manual_payment((select id from public.agreements where status='ACTIVE'),160,now() - interval '40 minutes','PAYID-MULTI','Synthetic multi-week')$$,
  'payment can cover multiple weeks'
);
select ok((select amount_paid=100 from public.payment_schedule_items where sequence_number=2)
  and (select amount_paid=100 from public.payment_schedule_items where sequence_number=3),'multi-week payment allocates FIFO');
select lives_ok(
  $$select public.record_manual_payment((select id from public.agreements where status='ACTIVE'),100,now() - interval '30 minutes','PAYID-ADVANCE','Synthetic advance')$$,
  'advance payment records'
);
select is((select amount_paid from public.payment_schedule_items where sequence_number=4),100::numeric,'advance payment allocates to a future obligation');
select is((select overdue_obligations from public.agreement_payment_summary where agreement_id=(select id from public.agreements where status='ACTIVE')),0,'paid past obligations are no longer overdue');

select lives_ok(
  $$select public.record_manual_payment((select id from public.agreements where status='ACTIVE'),350,now() - interval '20 minutes','PAYID-EXCESS','Synthetic excess')$$,
  'excess payment is retained'
);
select is((select unallocated_amount from public.payment_transactions where reference='PAYID-EXCESS'),150::numeric,'unallocated money is explicit');
select throws_ok(
  $$update public.payment_transactions set notes='overwrite' where reference='PAYID-EXACT'$$,
  '42501',null,'payment transaction is immutable'
);
select lives_ok(
  $$select public.reverse_manual_payment((select id from public.payment_transactions where reference='PAYID-PART'),'Synthetic correction')$$,
  'payment reversal creates a compensating transaction'
);
select ok((select count(*)=1 from public.payment_transactions where transaction_type='RECEIPT' and reference='PAYID-PART')
  and (select count(*)=1 from public.payment_transactions where transaction_type='REVERSAL' and reverses_transaction_id=(select id from public.payment_transactions where reference='PAYID-PART')),
  'reversal preserves the original receipt');
select ok((select count(*) >= 1 from public.audit_events where action='PAYMENT_REVERSED'),'reversal is audited');

set local role postgres;
insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values('41000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000002',now()-interval '2 days',100,'ACTIVE','31000000-0000-4000-8000-000000000001');
update public.vehicles set operational_status='ASSIGNED' where id='51000000-0000-4000-8000-000000000002';
set local role authenticated;select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
select public.create_agreement('41000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000002','WEEKLY_RENTAL',current_date,current_date,current_date,125);
select public.transition_agreement((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000002'),'PENDING_SIGNATURE');
select public.transition_agreement((select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000002'),'ACTIVE');
select is((select count(*)::integer from public.payment_schedule_items where agreement_id=(select id from public.agreements where vehicle_id='51000000-0000-4000-8000-000000000002')),1,'a same-day bounded agreement creates one obligation');

select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.agreements),0,'unauthorized authenticated user is denied reads');
select throws_ok(
  $$select public.record_manual_payment('00000000-0000-0000-0000-000000000000',100,now(),null,null)$$,
  '42501','staff access required','unauthorized user cannot record payment'
);
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000003',true);
select throws_ok(
  $$select public.generate_payment_schedule('00000000-0000-0000-0000-000000000000',current_date)$$,
  '42501','staff access required','inactive staff cannot mutate schedules'
);

select * from finish();
rollback;
