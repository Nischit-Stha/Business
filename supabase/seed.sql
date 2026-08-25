-- Synthetic local-development fixtures only. These people and identifiers are fictional.
insert into public.customers
  (id, full_name, phone, email, address, licence_number, licence_expiry, status)
values
  ('10000000-0000-4000-8000-000000000001', 'Avery Example', '0400 000 101',
   'avery@example.test', '1 Example Street, Melbourne VIC', 'SYNTH-A1001', '2029-06-30', 'ACTIVE'),
  ('10000000-0000-4000-8000-000000000002', 'Jordan Sample', '0400 000 102',
   'jordan@example.test', '2 Sample Road, Melbourne VIC', 'SYNTH-J1002', '2028-11-15', 'ACTIVE');

insert into public.vehicles
  (id, registration, vin, make, model, year, odometer, operational_status, weekly_rate)
values
  ('20000000-0000-4000-8000-000000000001', 'SYN001', 'SYNTHETICVIN00001', 'Toyota', 'Corolla', 2022, 42100, 'AVAILABLE', 420.00),
  ('20000000-0000-4000-8000-000000000002', 'SYN002', 'SYNTHETICVIN00002', 'Hyundai', 'i30', 2023, 28400, 'AVAILABLE', 440.00),
  ('20000000-0000-4000-8000-000000000003', 'SYN003', null, 'Kia', 'Cerato', 2021, 61750, 'WORKSHOP', 400.00);

-- Browser-test identities. Synthetic, local-only and reset with the local database.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,confirmation_token,recovery_token,email_change_token_new,email_change,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('91000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','e2e.staff@example.test',crypt('Synthetic-Staff-2026!',gen_salt('bf')),now(),'','','','',jsonb_build_object('provider','email','providers',array['email']),'{}',now(),now()),
('91000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','e2e.customer.a@example.test',crypt('Synthetic-Customer-A-2026!',gen_salt('bf')),now(),'','','','',jsonb_build_object('provider','email','providers',array['email']),'{}',now(),now()),
('91000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','e2e.customer.b@example.test',crypt('Synthetic-Customer-B-2026!',gen_salt('bf')),now(),'','','','',jsonb_build_object('provider','email','providers',array['email']),'{}',now(),now());
insert into auth.identities(provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) select id::text,id,jsonb_build_object('sub',id::text,'email',email,'email_verified',true),'email',now(),now(),now() from auth.users where id in ('91000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000003');
insert into public.staff_profiles(user_id,full_name,role) values('91000000-0000-4000-8000-000000000001','Synthetic E2E Administrator','ADMIN');
insert into public.customer_portal_accounts(user_id,customer_id,status,created_by) values
('91000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','ACTIVE','91000000-0000-4000-8000-000000000001'),
('91000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','ACTIVE','91000000-0000-4000-8000-000000000001');
