-- Optional synthetic scale extension. Apply after seed.sql and seed.uat.sql.
-- Produces exactly 500 vehicles and 335 customers without external/real data.
begin;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
insert into public.vehicles(id,registration,vin,make,model,year,odometer,operational_status,weekly_rate)
select md5('uat-vehicle-'||g)::uuid,'UAT'||lpad(g::text,3,'0'),'SYNTHUATVIN'||lpad(g::text,6,'0'),(array['Toyota','Hyundai','Kia','Mazda'])[1+(g%4)],(array['Corolla','i30','Cerato','Mazda 3'])[1+(g%4)],2019+(g%7),15000+(g*347),'AVAILABLE',390+(g%8)*10 from generate_series(148,497)g on conflict do nothing;
insert into public.customers(id,full_name,phone,email,address,licence_number,licence_expiry,status)
select md5('uat-customer-'||g)::uuid,'Synthetic Driver '||lpad(g::text,3,'0'),'0400 '||lpad((200000+g)::text,6,'0'),'driver.'||lpad(g::text,3,'0')||'@example.test',g||' Synthetic Avenue, Melbourne VIC','UAT-LIC-'||lpad(g::text,4,'0'),current_date+365+(g%365),'ACTIVE' from generate_series(99,333)g on conflict do nothing;
insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by)
select v.id,t,'VALID',current_date-30,current_date+335,'91000000-0000-4000-8000-000000000001' from public.vehicles v cross join(values('REGISTRATION'),('RWC'))d(t) on conflict(vehicle_id,compliance_type)do nothing;
insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer,service_interval_km,status)
select id,greatest(0,odometer-7000),10000,'OK' from public.vehicles on conflict(vehicle_id)do nothing;
commit;
