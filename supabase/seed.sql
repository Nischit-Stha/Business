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
