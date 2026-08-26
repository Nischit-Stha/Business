-- Veera V2 staging/UAT dataset. Synthetic data only.
-- Apply only after the normal seed to an isolated local or staging project.
-- This file is additive and idempotent; it must never be run in production.

begin;

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);

do $$
begin
  if current_setting('app.veera_runtime_mode', true) not in ('trial', 'staging', 'development') then
    raise notice 'Runtime mode is not set; operator must independently confirm this is an isolated non-production project';
  end if;
end $$;

-- Bring the fleet to 150 vehicles and the customer list to 100 people.
insert into public.vehicles(id,registration,vin,make,model,year,odometer,operational_status,weekly_rate)
select md5('uat-vehicle-'||g)::uuid,
       'UAT'||lpad(g::text,3,'0'),
       'SYNTHUATVIN'||lpad(g::text,6,'0'),
       (array['Toyota','Hyundai','Kia','Mazda'])[1+(g%4)],
       (array['Corolla','i30','Cerato','Mazda 3'])[1+(g%4)],
       2019+(g%7), 15000+(g*347), 'AVAILABLE', 390+(g%8)*10
from generate_series(1,147) g
on conflict do nothing;

insert into public.customers(id,full_name,phone,email,address,licence_number,licence_expiry,status)
select md5('uat-customer-'||g)::uuid,
       'Synthetic Driver '||lpad(g::text,3,'0'),
       '0400 '||lpad((200000+g)::text,6,'0'),
       'driver.'||lpad(g::text,3,'0')||'@example.test',
       g||' Synthetic Avenue, Melbourne VIC',
       'UAT-LIC-'||lpad(g::text,4,'0'),
       current_date+365+(g%365), 'ACTIVE'
from generate_series(1,98) g
on conflict do nothing;

update public.customer_approvals
set status='APPROVED',decided_by='91000000-0000-4000-8000-000000000001',decided_at=now(),reason_notes='Synthetic UAT approval'
where customer_id in (select md5('uat-customer-'||g)::uuid from generate_series(1,98) g)
  and status='PENDING';

insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at)
select md5('uat-customer-'||g)::uuid,t,'VERIFIED',current_date+365,
       '91000000-0000-4000-8000-000000000001',now()
from generate_series(1,98) g cross join (values('DRIVER_LICENCE'),('PROOF_OF_ADDRESS')) d(t)
on conflict(customer_id,document_type) do nothing;

update public.customer_documents set status='SUBMITTED',verified_by=null,verified_at=null
where customer_id=md5('uat-customer-98')::uuid and document_type='PROOF_OF_ADDRESS';

insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by)
select v.id,t,'VALID',current_date-30,current_date+335,'91000000-0000-4000-8000-000000000001'
from public.vehicles v cross join (values('REGISTRATION'),('RWC')) d(t)
on conflict(vehicle_id,compliance_type) do nothing;

insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer,service_interval_km,status)
select id,greatest(0,odometer-7000),10000,'OK' from public.vehicles
on conflict(vehicle_id) do nothing;

-- 59 generated active rentals plus the portal customer's rental.
insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by)
select md5('uat-assignment-'||g)::uuid,md5('uat-customer-'||g)::uuid,md5('uat-vehicle-'||g)::uuid,
       now()-((35+(g%90))||' days')::interval,15000+(g*347)-1500,'ACTIVE','91000000-0000-4000-8000-000000000001'
from generate_series(1,59) g on conflict do nothing;

insert into public.vehicle_assignments(id,customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by)
values(md5('uat-assignment-portal')::uuid,'10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',now()-interval '28 days',40500,'ACTIVE','91000000-0000-4000-8000-000000000001')
on conflict do nothing;

update public.vehicles v set operational_status='ASSIGNED'
where exists(select 1 from public.vehicle_assignments a where a.vehicle_id=v.id and a.assignment_status='ACTIVE');

insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,first_due_date,weekly_amount,deposit_amount,agreed_payment_count,created_by,signed_at)
select md5('uat-agreement-'||g)::uuid,md5('uat-customer-'||g)::uuid,md5('uat-vehicle-'||g)::uuid,
       case when g%8=0 then 'RENT_TO_OWN' else 'WEEKLY_RENTAL' end,'ACTIVE',current_date-35,current_date-28,
       390+(g%8)*10,0,case when g%8=0 then 104 end,'91000000-0000-4000-8000-000000000001',now()-interval '35 days'
from generate_series(1,59) g on conflict do nothing;

insert into public.agreements(id,customer_id,vehicle_id,agreement_type,status,start_date,first_due_date,weekly_amount,deposit_amount,created_by,signed_at)
values(md5('uat-agreement-portal')::uuid,'10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','WEEKLY_RENTAL','ACTIVE',current_date-28,current_date-21,420,0,'91000000-0000-4000-8000-000000000001',now()-interval '28 days')
on conflict do nothing;

insert into public.payment_schedule_items(agreement_id,sequence_number,due_date,amount_due,status,amount_paid,paid_at)
select a.id,s,a.first_due_date+(s-1)*7,a.weekly_amount,
       case
         when a.customer_id=md5('uat-customer-2')::uuid then 'PAID'
         when a.customer_id=md5('uat-customer-1')::uuid and a.first_due_date+(s-1)*7<current_date then 'OVERDUE'
         when a.first_due_date+(s-1)*7<current_date then 'PAID'
         when a.first_due_date+(s-1)*7=current_date then 'DUE'
         else 'UPCOMING' end,
       case when a.customer_id=md5('uat-customer-2')::uuid or (a.customer_id<>md5('uat-customer-1')::uuid and a.first_due_date+(s-1)*7<current_date) then a.weekly_amount else 0 end,
       case when a.customer_id=md5('uat-customer-2')::uuid or (a.customer_id<>md5('uat-customer-1')::uuid and a.first_due_date+(s-1)*7<current_date) then now()-interval '1 day' end
from public.agreements a cross join generate_series(1,26) s
where a.id=md5('uat-agreement-portal')::uuid or a.id in(select md5('uat-agreement-'||g)::uuid from generate_series(1,59) g)
on conflict(agreement_id,sequence_number) do nothing;

-- Demonstration states: upcoming service, expired compliance, open issue, today's movements.
update public.maintenance_plans set last_completed_service_odometer=(select odometer-9000 from public.vehicles where id=md5('uat-vehicle-60')::uuid)
where vehicle_id=md5('uat-vehicle-60')::uuid;
update public.vehicle_compliance set status='EXPIRED',expires_at=current_date-5
where vehicle_id='20000000-0000-4000-8000-000000000003' and compliance_type='REGISTRATION';

insert into public.vehicle_issues(id,vehicle_id,customer_id,agreement_id,created_by,severity,category,description,status)
values(md5('uat-open-issue')::uuid,md5('uat-vehicle-3')::uuid,md5('uat-customer-3')::uuid,md5('uat-agreement-3')::uuid,
       '91000000-0000-4000-8000-000000000001','MEDIUM','WARNING_LIGHT','Synthetic dashboard warning light reported during UAT','OPEN')
on conflict do nothing;

insert into public.pickup_checklists(agreement_id,customer_id,vehicle_id,status,scheduled_at,staff_notes)
values(md5('uat-agreement-portal')::uuid,'10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','READY',date_trunc('day',now())+interval '10 hours','Synthetic pickup today')
on conflict(agreement_id) do nothing;
insert into public.return_checklists(assignment_id,status,scheduled_at,staff_notes)
values(md5('uat-assignment-1')::uuid,'READY',date_trunc('day',now())+interval '16 hours','Synthetic return today')
on conflict(assignment_id) do nothing;

insert into public.customer_portal_requests(id,customer_id,request_type,pickup_id,requested_for,customer_note,status,created_by)
values(md5('uat-portal-request')::uuid,'10000000-0000-4000-8000-000000000001','PICKUP_RESCHEDULE',(select id from public.pickup_checklists where agreement_id=md5('uat-agreement-portal')::uuid),now()+interval '2 days','Synthetic request for UAT','SUBMITTED','91000000-0000-4000-8000-000000000002')
on conflict do nothing;

insert into public.toll_fine_notices(id,type,external_reference,vehicle_id,registration,event_at,issued_at,amount,source,status,match_confidence)
values(md5('uat-toll-review')::uuid,'TOLL','UAT-TOLL-REVIEW',md5('uat-vehicle-3')::uuid,'UAT003',now()-interval '4 days',now()-interval '2 days',18.75,'SYNTHETIC','NEEDS_REVIEW','AMBIGUOUS')
on conflict do nothing;

insert into public.notifications(customer_id,vehicle_id,agreement_id,type,channel,template_key,subject,rendered_message,scheduled_for,sent_at,delivered_at,status,provider_message_id,created_by,dedup_key,recipient,max_retries,manual)
values
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',md5('uat-agreement-portal')::uuid,'PAYMENT_RECEIVED','SMS','PAYMENT_RECEIVED',null,'Synthetic payment received notification',now()-interval '2 hours',now()-interval '2 hours',now()-interval '119 minutes','DELIVERED','local-uat-payment','91000000-0000-4000-8000-000000000001','uat-payment-received','0400 000 101',3,false),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',md5('uat-agreement-portal')::uuid,'PICKUP_REMINDER','SMS','PICKUP_REMINDER',null,'Synthetic pickup reminder',now()+interval '1 hour',null,null,'SCHEDULED',null,'91000000-0000-4000-8000-000000000001','uat-pickup-reminder','0400 000 101',3,false)
on conflict(dedup_key) do nothing;

-- Ambiguous synthetic bank receipt stays unposted for staff reconciliation.
insert into public.import_batches(id,source,source_identifier,checksum,row_count,imported_by,status,result)
values(md5('uat-import-batch')::uuid,'SYNTHETIC_CSV','uat-demo.csv',repeat('a',64),1,'91000000-0000-4000-8000-000000000001','COMPLETED','{"synthetic":true}')
on conflict do nothing;
insert into public.imported_bank_transactions(id,external_transaction_id,source,transaction_date,received_at,amount,payer_name_raw,description,reference_raw,status,import_batch_id)
values(md5('uat-ambiguous-payment')::uuid,'UAT-AMBIGUOUS-001','SYNTHETIC_CSV',current_date,now()-interval '3 hours',420,'Synthetic Payer','Synthetic ambiguous weekly payment','UAT-AMB','REVIEW_REQUIRED',md5('uat-import-batch')::uuid)
on conflict do nothing;

commit;
