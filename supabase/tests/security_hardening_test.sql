begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('39600000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','security.admin@example.test','',now(),now(),now()),
('39600000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','security.customer@example.test','',now(),now(),now());
insert into public.staff_profiles(user_id,full_name,role) values('39600000-0000-4000-8000-000000000001','Synthetic Security Admin','ADMIN');
insert into public.customers(id,full_name,phone,email,licence_number,licence_expiry,status) values('49600000-0000-4000-8000-000000000001','Synthetic Security Customer','+61400000601','security.customer@example.test','SECURITY-ONLY',current_date+30,'ACTIVE');
insert into public.customer_portal_accounts(user_id,customer_id,created_by) values('39600000-0000-4000-8000-000000000002','49600000-0000-4000-8000-000000000001','39600000-0000-4000-8000-000000000001');

set local role authenticated; select set_config('request.jwt.claim.sub','39600000-0000-4000-8000-000000000002',true);
select is(public.consume_action_budget('PORTAL_ISSUE',2,3600),true,'authenticated customer can consume allowed budget');
select is(public.consume_action_budget('PORTAL_ISSUE',2,3600),true,'budget permits configured count');
select is(public.consume_action_budget('PORTAL_ISSUE',2,3600),false,'budget fails closed above limit');
select is((select count(*)::int from public.security_events),0,'customer cannot read security telemetry');
select throws_ok($$update public.security_events set context='{}'$$,'42501',null,'customer cannot mutate security telemetry');

select set_config('request.jwt.claim.sub','39600000-0000-4000-8000-000000000001',true);
select is((select count(*)::int from public.security_events where event_type='RATE_LIMIT_EXCEEDED'),1,'administrator can read minimized rate-limit telemetry');
select throws_ok($$delete from public.security_events$$,'42501',null,'security telemetry mutation permission is denied for administrator');
reset role; set local role anon;
select throws_ok($$select public.consume_action_budget('PORTAL_ISSUE',2,3600)$$,'42501',null,'anonymous invocation is denied');

select * from finish(); rollback;
