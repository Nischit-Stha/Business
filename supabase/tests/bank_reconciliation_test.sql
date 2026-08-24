begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('3a000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bank.staff@example.test','',now(),now(),now()),
('3a000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bank.outsider@example.test','',now(),now(),now()),
('3a000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bank.inactive@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name) values('3a000000-0000-4000-8000-000000000001','Bank Test Staff');
insert into public.staff_profiles(user_id,full_name,status,is_active) values('3a000000-0000-4000-8000-000000000003','Inactive Bank Staff','DISABLED',false);
insert into public.customers(id,full_name,phone,licence_number) values
('4a000000-0000-4000-8000-000000000001','Synthetic Alex','0400000001','BANK-1'),
('4a000000-0000-4000-8000-000000000002','Shared Synthetic','0400000002','BANK-2'),
('4a000000-0000-4000-8000-000000000003','Shared Synthetic','0400000003','BANK-3');
insert into public.vehicles(id,registration,make,model,year,weekly_rate) values
('5a000000-0000-4000-8000-000000000001','BNK001','Synthetic','One',2026,100),
('5a000000-0000-4000-8000-000000000002','BNK002','Synthetic','Two',2026,100),
('5a000000-0000-4000-8000-000000000003','BNK003','Synthetic','Three',2026,100);
insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,end_date,first_due_date,weekly_amount,created_by) values
('6a000000-0000-4000-8000-000000000001','4a000000-0000-4000-8000-000000000001','5a000000-0000-4000-8000-000000000001','WEEKLY_RENTAL','ACTIVE',current_date-21,current_date+35,current_date-14,100,'3a000000-0000-4000-8000-000000000001'),
('6a000000-0000-4000-8000-000000000002','4a000000-0000-4000-8000-000000000002','5a000000-0000-4000-8000-000000000002','WEEKLY_RENTAL','ACTIVE',current_date-7,current_date+35,current_date,100,'3a000000-0000-4000-8000-000000000001'),
('6a000000-0000-4000-8000-000000000003','4a000000-0000-4000-8000-000000000003','5a000000-0000-4000-8000-000000000003','WEEKLY_RENTAL','ACTIVE',current_date-7,current_date+35,current_date,100,'3a000000-0000-4000-8000-000000000001');
insert into public.payment_schedule_items(agreement_id,sequence_number,due_date,amount_due,status) values
('6a000000-0000-4000-8000-000000000001',1,current_date-14,100,'OVERDUE'),
('6a000000-0000-4000-8000-000000000001',2,current_date-7,100,'OVERDUE'),
('6a000000-0000-4000-8000-000000000001',3,current_date,100,'DUE'),
('6a000000-0000-4000-8000-000000000001',4,current_date+7,100,'UPCOMING'),
('6a000000-0000-4000-8000-000000000002',1,current_date,100,'DUE'),
('6a000000-0000-4000-8000-000000000003',1,current_date,100,'DUE');
insert into public.reminder_actions(agreement_id,customer_id,stage,overdue_amount) values('6a000000-0000-4000-8000-000000000001','4a000000-0000-4000-8000-000000000001','FIRST',200);

set local role authenticated;
select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

select lives_ok($$select public.import_synthetic_bank_csv('first.csv',repeat('a',64),'[
 {"external_transaction_id":"BANK-HIGH","transaction_date":"2026-08-24","received_at":"2026-08-24T09:00:00+10:00","amount":"400","description":"Synthetic exact","payer_name_raw":"Synthetic Alex","reference_raw":"weekly"},
 {"external_transaction_id":"BANK-AMB","transaction_date":"2026-08-24","received_at":"2026-08-24T09:01:00+10:00","amount":"100","description":"Synthetic ambiguous","payer_name_raw":"Shared Synthetic","reference_raw":"weekly"},
 {"external_transaction_id":"BANK-NONE","transaction_date":"2026-08-24","received_at":"2026-08-24T09:02:00+10:00","amount":"63","description":"Unknown synthetic","payer_name_raw":"Nobody Synthetic","reference_raw":"unknown"},
 {"external_transaction_id":"BANK-PART","transaction_date":"2026-08-24","received_at":"2026-08-24T09:03:00+10:00","amount":"40","description":"Synthetic partial","payer_name_raw":"Synthetic Alex","reference_raw":"partial"},
 {"external_transaction_id":"BANK-MULTI","transaction_date":"2026-08-24","received_at":"2026-08-24T09:04:00+10:00","amount":"200","description":"Synthetic multiple","payer_name_raw":"Synthetic Alex","reference_raw":"multiple"},
 {"external_transaction_id":"BANK-EXCESS","transaction_date":"2026-08-24","received_at":"2026-08-24T09:05:00+10:00","amount":"250","description":"Synthetic excess","payer_name_raw":"Synthetic Alex","reference_raw":"excess"}
]'::jsonb)$$,'synthetic CSV rows import');
select is((select count(*)::int from public.imported_bank_transactions),6,'all valid imported rows are durable');
select lives_ok($$select public.import_synthetic_bank_csv('first-again.csv',repeat('a',64),'[]'::jsonb)$$,'same checksum rerun is idempotent');
select is((select count(*)::int from public.import_batches),1,'same checksum does not create another batch');
select lives_ok($$select public.import_synthetic_bank_csv('duplicate.csv',repeat('b',64),'[{"external_transaction_id":"BANK-HIGH","transaction_date":"2026-08-24","received_at":"2026-08-24T09:00:00+10:00","amount":"400"}]'::jsonb)$$,'duplicate external transaction import completes safely');
select is((select count(*)::int from public.imported_bank_transactions where external_transaction_id='BANK-HIGH'),1,'duplicate external transaction is blocked');
select is((select confidence from public.bank_match_runs m join public.imported_bank_transactions t on t.id=m.imported_bank_transaction_id where t.external_transaction_id='BANK-HIGH'),'HIGH','exact amount and exact name produce HIGH match');
select is((select confidence from public.bank_match_runs m join public.imported_bank_transactions t on t.id=m.imported_bank_transaction_id where t.external_transaction_id='BANK-AMB'),'AMBIGUOUS','equal candidates produce AMBIGUOUS match');
select is((select status from public.imported_bank_transactions where external_transaction_id='BANK-AMB'),'REVIEW_REQUIRED','ambiguous receipt requires review');
select is((select confidence from public.bank_match_runs m join public.imported_bank_transactions t on t.id=m.imported_bank_transaction_id where t.external_transaction_id='BANK-NONE'),'NO_MATCH','unknown receipt produces NO_MATCH');
select is((select count(*)::int from public.operational_exceptions where exception_type='SUSPICIOUS_BANK_DUPLICATE' and status<>'RESOLVED'),1,'duplicate exception is deduplicated');

select lives_ok(format($sql$select public.reconcile_bank_transaction((select id from public.imported_bank_transactions where external_transaction_id='BANK-PART'),'[{"agreement_id":"6a000000-0000-4000-8000-000000000001","amount":40}]','Staff verified synthetic payer',(select id from public.bank_match_runs where imported_bank_transaction_id=(select id from public.imported_bank_transactions where external_transaction_id='BANK-PART')))$sql$),'partial receipt reconciles');
select is((select amount_paid from public.payment_schedule_items where agreement_id='6a000000-0000-4000-8000-000000000001' and sequence_number=1),40::numeric,'partial payment allocates FIFO');
select lives_ok($$select public.reconcile_bank_transaction((select id from public.imported_bank_transactions where external_transaction_id='BANK-MULTI'),'[{"agreement_id":"6a000000-0000-4000-8000-000000000001","amount":200}]','Staff verified multiple weeks',null)$$,'multiple-week receipt reconciles');
select ok((select amount_paid=100 from public.payment_schedule_items where agreement_id='6a000000-0000-4000-8000-000000000001' and sequence_number=1) and (select amount_paid=100 from public.payment_schedule_items where agreement_id='6a000000-0000-4000-8000-000000000001' and sequence_number=2) and (select amount_paid=40 from public.payment_schedule_items where agreement_id='6a000000-0000-4000-8000-000000000001' and sequence_number=3),'multiple-week payment fills oldest obligations');
select lives_ok($$select public.reconcile_bank_transaction((select id from public.imported_bank_transactions where external_transaction_id='BANK-EXCESS'),'[{"agreement_id":"6a000000-0000-4000-8000-000000000001","amount":250}]','Staff verified advance and excess',null)$$,'advance/excess receipt reconciles');
select is((select amount_paid from public.payment_schedule_items where agreement_id='6a000000-0000-4000-8000-000000000001' and sequence_number=4),100::numeric,'advance money allocates to future obligation');
select is((select unallocated_amount from public.payment_transactions p join public.bank_payment_postings b on b.payment_transaction_id=p.id join public.imported_bank_transactions t on t.id=b.imported_bank_transaction_id where t.external_transaction_id='BANK-EXCESS'),90::numeric,'excess remains explicit and is never discarded');
select throws_ok($$select public.reconcile_bank_transaction((select id from public.imported_bank_transactions where external_transaction_id='BANK-PART'),'[{"agreement_id":"6a000000-0000-4000-8000-000000000001","amount":40}]','Duplicate posting',null)$$,'P0001','bank receipt already financially posted','duplicate financial posting is prevented');
select is((select overdue_amount from public.agreement_payment_summary where agreement_id='6a000000-0000-4000-8000-000000000001'),0::numeric,'reconciled payments clear overdue state');
select is((select status from public.reminder_actions where agreement_id='6a000000-0000-4000-8000-000000000001'),'CANCELLED','queued reminder is cancelled');
select ok((select count(*)>0 from public.bank_match_candidates c join public.bank_match_runs m on m.id=c.match_run_id join public.imported_bank_transactions t on t.id=m.imported_bank_transaction_id where t.external_transaction_id='BANK-PART') and (select count(*)>0 from public.bank_reconciliation_actions a join public.imported_bank_transactions t on t.id=a.imported_bank_transaction_id where t.external_transaction_id='BANK-PART' and a.action in ('CONFIRMED','OVERRIDDEN')),'manual override retains original evidence and action');
select lives_ok($$select public.reverse_bank_reconciliation((select id from public.imported_bank_transactions where external_transaction_id='BANK-PART'),'Synthetic chargeback correction')$$,'reversal creates compensating history');
select ok((select status='REVERSED' from public.imported_bank_transactions where external_transaction_id='BANK-PART') and exists(select 1 from public.payment_transactions where transaction_type='REVERSAL' and reverses_transaction_id=(select payment_transaction_id from public.bank_payment_postings b join public.imported_bank_transactions t on t.id=b.imported_bank_transaction_id where t.external_transaction_id='BANK-PART')),'reversal preserves original receipt and adds compensation');
select is((select count(*)::int from public.operational_exceptions where exception_type='AMBIGUOUS_BANK_MATCH' and status<>'RESOLVED'),1,'ambiguous exception is deduplicated');

select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000002',true);
select is((select count(*)::int from public.imported_bank_transactions),0,'unauthorized user is denied reconciliation reads');
select throws_ok($$select public.ignore_bank_transaction('00000000-0000-0000-0000-000000000000','No access')$$,'42501','staff access required','unauthorized user cannot mutate reconciliation');
select set_config('request.jwt.claim.sub','3a000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.import_synthetic_bank_csv('inactive.csv',repeat('c',64),'[]')$$,'42501','staff access required','inactive staff cannot import');

select * from finish();
rollback;
