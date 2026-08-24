-- Automated maintenance exposure and compliance attention.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED','MAINTENANCE_RECORD_CREATED','MAINTENANCE_RECORD_STATUS_CHANGED','MAINTENANCE_RECORD_COMPLETED','SERVICE_INTERVAL_CHANGED','COMPLIANCE_ATTENTION_REFRESHED'
));

create table public.maintenance_service_records (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id),
  service_type text not null check(service_type in ('SCHEDULED_SERVICE','OIL_CHANGE','TYRES','BRAKES','BATTERY','REPAIR','INSPECTION','OTHER')),
  odometer_at_service integer check(odometer_at_service is null or odometer_at_service>=0),
  service_date date,
  next_service_odometer integer check(next_service_odometer is null or next_service_odometer>=0),
  next_service_date date,
  cost numeric(12,2) check(cost is null or cost>=0),
  notes text check(notes is null or length(notes)<=2000),
  status text not null check(status in ('SCHEDULED','DUE_SOON','OVERDUE','IN_PROGRESS','COMPLETED','CANCELLED')),
  performed_by uuid references public.staff_profiles(user_id),
  created_by uuid not null references public.staff_profiles(user_id),
  scheduled_for date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint maintenance_record_completion check((status='COMPLETED' and odometer_at_service is not null and service_date is not null and performed_by is not null and completed_at is not null) or status<>'COMPLETED')
);
create index maintenance_service_vehicle_history on public.maintenance_service_records(vehicle_id,service_date desc,created_at desc);
create index maintenance_service_active on public.maintenance_service_records(status,scheduled_for) where status not in ('COMPLETED','CANCELLED');
create trigger maintenance_service_touch_updated_at before update on public.maintenance_service_records for each row execute function app_private.touch_updated_at();
alter table public.maintenance_service_records enable row level security;
create policy staff_read_maintenance_service on public.maintenance_service_records for select to authenticated using(app_private.is_staff());
revoke all on public.maintenance_service_records from anon,authenticated;
grant select on public.maintenance_service_records to authenticated;

create or replace view public.vehicle_maintenance_status with (security_invoker=true) as
select v.id vehicle_id,v.odometer,p.last_completed_service_odometer,coalesce(p.service_interval_km,10000) service_interval_km,p.next_service_odometer,
  case when exists(select 1 from public.maintenance_jobs j where j.vehicle_id=v.id and j.status in ('OPEN','IN_PROGRESS')) or exists(select 1 from public.maintenance_service_records r where r.vehicle_id=v.id and r.status='IN_PROGRESS') then 'IN_PROGRESS'
       when p.next_service_odometer is null then 'NOT_CONFIGURED'
       when v.odometer>=p.next_service_odometer then 'OVERDUE'
       when v.odometer>=p.next_service_odometer-1500 then 'DUE_SOON'
       else 'OK' end status,
  case when p.next_service_odometer is null then null else p.next_service_odometer-v.odometer end km_remaining,
  (select max(r.service_date) from public.maintenance_service_records r where r.vehicle_id=v.id and r.status='COMPLETED') last_service_date
from public.vehicles v left join public.maintenance_plans p on p.vehicle_id=v.id;

create or replace view public.vehicle_compliance_exposure with (security_invoker=true) as
select v.id vehicle_id,v.registration,required.compliance_type,c.status stored_status,c.expires_at,
  case when c.id is null or c.expires_at is null then 'MISSING'
       when c.expires_at<current_date then 'EXPIRED'
       when c.expires_at<=current_date+7 then 'DUE_7'
       when c.expires_at<=current_date+14 then 'DUE_14'
       when c.expires_at<=current_date+30 then 'DUE_30'
       else 'VALID' end exposure
from public.vehicles v cross join (values('REGISTRATION'),('RWC')) required(compliance_type)
left join public.vehicle_compliance c on c.vehicle_id=v.id and c.compliance_type=required.compliance_type;
grant select on public.vehicle_maintenance_status,public.vehicle_compliance_exposure to authenticated;

create or replace view public.fleet_operations with (security_invoker=true) as
select v.id,v.registration,v.make,v.model,v.year,v.odometer,v.operational_status,
  c.id current_customer_id,c.full_name current_customer,a.id agreement_id,a.status agreement_status,
  p.scheduled_at next_pickup_at,r.scheduled_at next_return_at,
  (select count(*) from public.vehicle_issues i where i.vehicle_id=v.id and i.status not in ('RESOLVED','CANCELLED')) open_issue_count,
  ms.status maintenance_status,
  (v.operational_status='AVAILABLE' and not app_private.vehicle_has_blocking_issue(v.id) and app_private.vehicle_is_compliant(v.id)
    and not exists(select 1 from public.maintenance_jobs mj where mj.vehicle_id=v.id and mj.status in ('OPEN','IN_PROGRESS'))
    and not exists(select 1 from public.maintenance_service_records mr where mr.vehicle_id=v.id and mr.status='IN_PROGRESS')) ready_for_allocation
from public.vehicles v
left join public.vehicle_assignments va on va.vehicle_id=v.id and va.assignment_status='ACTIVE'
left join public.customers c on c.id=va.customer_id
left join public.agreements a on a.vehicle_id=v.id and a.customer_id=va.customer_id and a.status in ('ACTIVE','SUSPENDED')
left join public.pickup_checklists p on p.vehicle_id=v.id and p.status not in ('COMPLETED','CANCELLED')
left join public.return_checklists r on r.assignment_id=va.id and r.status not in ('COMPLETED','CANCELLED')
left join public.vehicle_maintenance_status ms on ms.vehicle_id=v.id;

create or replace function public.set_vehicle_service_interval(p_vehicle_id uuid,p_interval_km integer) returns public.maintenance_plans language plpgsql security definer set search_path='' as $$
declare p public.maintenance_plans; old_interval integer;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_interval_km not between 1000 and 50000 then raise exception 'service interval must be between 1000 and 50000 km' using errcode='22023'; end if;
 select service_interval_km into old_interval from public.maintenance_plans where vehicle_id=p_vehicle_id;
 insert into public.maintenance_plans(vehicle_id,service_interval_km) values(p_vehicle_id,p_interval_km) on conflict(vehicle_id) do update set service_interval_km=excluded.service_interval_km returning * into p;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'SERVICE_INTERVAL_CHANGED','vehicle',p_vehicle_id,jsonb_build_object('from',old_interval,'to',p_interval_km)); return p; end $$;

create or replace function public.create_maintenance_record(p_vehicle_id uuid,p_service_type text,p_scheduled_for date,p_next_service_date date,p_cost numeric,p_notes text) returns public.maintenance_service_records language plpgsql security definer set search_path='' as $$
declare r public.maintenance_service_records;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 insert into public.maintenance_plans(vehicle_id) values(p_vehicle_id) on conflict do nothing;
 insert into public.maintenance_service_records(vehicle_id,service_type,status,scheduled_for,next_service_date,cost,notes,created_by) values(p_vehicle_id,p_service_type,'SCHEDULED',p_scheduled_for,p_next_service_date,p_cost,nullif(btrim(p_notes),''),auth.uid()) returning * into r;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'MAINTENANCE_RECORD_CREATED','maintenance_service_record',r.id,jsonb_build_object('vehicle_id',p_vehicle_id,'service_type',p_service_type,'scheduled_for',p_scheduled_for)); return r; end $$;

create or replace function public.update_maintenance_record_status(p_record_id uuid,p_status text,p_notes text default null) returns public.maintenance_service_records language plpgsql security definer set search_path='' as $$
declare r public.maintenance_service_records; old_status text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_status not in ('SCHEDULED','DUE_SOON','OVERDUE','IN_PROGRESS','CANCELLED') then raise exception 'invalid maintenance status transition' using errcode='22023'; end if;
 select status into old_status from public.maintenance_service_records where id=p_record_id and status not in ('COMPLETED','CANCELLED') for update; if not found then raise exception 'active maintenance record not found'; end if;
 update public.maintenance_service_records set status=p_status,notes=coalesce(nullif(btrim(p_notes),''),notes) where id=p_record_id returning * into r;
 if p_status='IN_PROGRESS' then update public.vehicles set operational_status='WORKSHOP' where id=r.vehicle_id; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'MAINTENANCE_RECORD_STATUS_CHANGED','maintenance_service_record',r.id,jsonb_build_object('from',old_status,'to',p_status)); return r; end $$;

create or replace function public.complete_maintenance_record(p_record_id uuid,p_odometer integer,p_service_date date,p_next_service_date date,p_cost numeric,p_notes text) returns public.maintenance_service_records language plpgsql security definer set search_path='' as $$
declare r public.maintenance_service_records; interval_km integer;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 select * into r from public.maintenance_service_records where id=p_record_id and status not in ('COMPLETED','CANCELLED') for update; if not found then raise exception 'active maintenance record not found'; end if;
 perform app_private.record_odometer(r.vehicle_id,p_odometer,'SERVICE',coalesce(p_service_date,current_date)::timestamptz+interval '12 hours');
 select service_interval_km into interval_km from public.maintenance_plans where vehicle_id=r.vehicle_id;
 update public.maintenance_service_records set status='COMPLETED',odometer_at_service=p_odometer,service_date=coalesce(p_service_date,current_date),next_service_odometer=case when service_type='SCHEDULED_SERVICE' then p_odometer+coalesce(interval_km,10000) end,next_service_date=p_next_service_date,cost=coalesce(p_cost,cost),notes=coalesce(nullif(btrim(p_notes),''),notes),performed_by=auth.uid(),completed_at=now() where id=p_record_id returning * into r;
 if r.service_type='SCHEDULED_SERVICE' then insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer,status) values(r.vehicle_id,p_odometer,'OK') on conflict(vehicle_id) do update set last_completed_service_odometer=excluded.last_completed_service_odometer,status='OK'; end if;
 if not app_private.vehicle_has_blocking_issue(r.vehicle_id) and not exists(select 1 from public.maintenance_jobs j where j.vehicle_id=r.vehicle_id and j.status in ('OPEN','IN_PROGRESS')) then update public.vehicles set operational_status=case when exists(select 1 from public.vehicle_assignments a where a.vehicle_id=r.vehicle_id and a.assignment_status='ACTIVE') then 'ASSIGNED' else 'AVAILABLE' end where id=r.vehicle_id and operational_status='WORKSHOP'; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'MAINTENANCE_RECORD_COMPLETED','maintenance_service_record',r.id,jsonb_build_object('vehicle_id',r.vehicle_id,'odometer',p_odometer,'service_type',r.service_type)); return r; end $$;

-- Preserve the existing workshop-job API while also writing the new historical service ledger.
create or replace function public.complete_maintenance_job(p_job_id uuid,p_odometer integer,p_notes text default null,p_cost numeric default null) returns public.maintenance_jobs language plpgsql security definer set search_path='' as $$
declare j public.maintenance_jobs; interval_km integer;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into j from public.maintenance_jobs where id=p_job_id and status in ('OPEN','IN_PROGRESS') for update; if not found then raise exception 'open maintenance job not found'; end if;
 perform app_private.record_odometer(j.vehicle_id,p_odometer,'SERVICE',now());
 update public.maintenance_jobs set status='COMPLETED',completed_at=now(),completion_odometer=p_odometer,completed_by=auth.uid(),notes=coalesce(nullif(btrim(p_notes),''),notes),cost=coalesce(p_cost,cost) where id=p_job_id returning * into j;
 insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer,status) values(j.vehicle_id,p_odometer,'OK') on conflict(vehicle_id) do update set last_completed_service_odometer=excluded.last_completed_service_odometer,status='OK';
 select service_interval_km into interval_km from public.maintenance_plans where vehicle_id=j.vehicle_id;
 insert into public.maintenance_service_records(vehicle_id,service_type,odometer_at_service,service_date,next_service_odometer,cost,notes,status,performed_by,created_by,completed_at) values(j.vehicle_id,'SCHEDULED_SERVICE',p_odometer,current_date,p_odometer+coalesce(interval_km,10000),j.cost,j.notes,'COMPLETED',auth.uid(),j.opened_by,now());
 update public.vehicles set operational_status=case when app_private.vehicle_has_blocking_issue(j.vehicle_id) then 'OFF_ROAD' when exists(select 1 from public.vehicle_assignments a where a.vehicle_id=j.vehicle_id and a.assignment_status='ACTIVE') then 'ASSIGNED' else 'AVAILABLE' end where id=j.vehicle_id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'MAINTENANCE_JOB_COMPLETED','maintenance_job',j.id,jsonb_build_object('vehicle_id',j.vehicle_id,'odometer',p_odometer)); return j; end $$;

create or replace function public.refresh_maintenance_compliance_attention() returns integer language plpgsql security definer set search_path='' as $$
declare x record; n integer:=0; sev text; summary text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 -- Retire exception keys created by the legacy refresh; automated keys below remain open and are updated in place.
 update public.operational_exceptions set status='RESOLVED',resolved_at=now(),resolution_note='Superseded by automated maintenance and compliance tracking'
 where status<>'RESOLVED' and (dedup_key like 'service:%' or dedup_key like 'registration:%' or dedup_key like 'rwc:%' or dedup_key like 'licence:%');
 for x in select * from public.vehicle_maintenance_status where status in ('DUE_SOON','OVERDUE') loop
   sev:=case x.status when 'OVERDUE' then 'HIGH' else 'MEDIUM' end; summary:=case x.status when 'OVERDUE' then 'Scheduled service overdue' else 'Scheduled service due within 1,500 km' end;
   perform app_private.upsert_exception(case x.status when 'OVERDUE' then 'SERVICE_OVERDUE' else 'SERVICE_DUE' end,sev,'vehicle',x.vehicle_id,'auto-service:'||x.vehicle_id,summary,jsonb_build_object('odometer',x.odometer,'next_service_odometer',x.next_service_odometer,'km_remaining',x.km_remaining),false,auth.uid()); n:=n+1;
 end loop;
 for x in select * from public.vehicle_compliance_exposure where exposure<>'VALID' loop
   sev:=case x.exposure when 'EXPIRED' then 'CRITICAL' when 'MISSING' then 'HIGH' when 'DUE_7' then 'HIGH' when 'DUE_14' then 'MEDIUM' else 'LOW' end;
   summary:=case when x.exposure='EXPIRED' then x.compliance_type||' expired' when x.exposure='MISSING' then x.compliance_type||' record missing' else x.compliance_type||' expires within '||replace(x.exposure,'DUE_','')||' days' end;
   perform app_private.upsert_exception(case x.compliance_type when 'REGISTRATION' then 'REGISTRATION_EXPIRY' else 'RWC_EXPIRY' end,sev,'vehicle',x.vehicle_id,'auto-compliance:'||lower(x.compliance_type)||':'||x.vehicle_id,summary,jsonb_build_object('expires_at',x.expires_at,'threshold',x.exposure),false,auth.uid()); n:=n+1;
 end loop;
 for x in select c.id,c.licence_expiry,exists(select 1 from public.agreements a where a.customer_id=c.id and a.status='ACTIVE') active_agreement from public.customers c where c.status='ACTIVE' and c.licence_expiry is not null and c.licence_expiry<=current_date+30 loop
   sev:=case when x.licence_expiry<current_date and x.active_agreement then 'HIGH' when x.licence_expiry<current_date then 'MEDIUM' when x.licence_expiry<=current_date+7 then 'HIGH' when x.licence_expiry<=current_date+14 then 'MEDIUM' else 'LOW' end;
   summary:=case when x.licence_expiry<current_date then case when x.active_agreement then 'Customer licence expired during active agreement' else 'Customer licence expired' end else 'Customer licence expiring soon' end;
   perform app_private.upsert_exception('LICENCE_EXPIRY',sev,'customer',x.id,'auto-licence:'||x.id,summary,jsonb_build_object('expires_at',x.licence_expiry,'active_agreement',x.active_agreement),x.active_agreement,auth.uid()); n:=n+1;
 end loop;
 update public.operational_exceptions e set status='RESOLVED',resolved_at=now(),resolution_note='Underlying service condition cleared' where e.status<>'RESOLVED' and e.dedup_key like 'auto-service:%' and not exists(select 1 from public.vehicle_maintenance_status s where s.vehicle_id=e.entity_id and s.status in ('DUE_SOON','OVERDUE'));
 update public.operational_exceptions e set status='RESOLVED',resolved_at=now(),resolution_note='Underlying vehicle compliance condition cleared' where e.status<>'RESOLVED' and e.dedup_key like 'auto-compliance:%' and not exists(select 1 from public.vehicle_compliance_exposure c where c.vehicle_id=e.entity_id and c.exposure<>'VALID' and e.dedup_key='auto-compliance:'||lower(c.compliance_type)||':'||c.vehicle_id);
 update public.operational_exceptions e set status='RESOLVED',resolved_at=now(),resolution_note='Underlying licence condition cleared' where e.status<>'RESOLVED' and e.dedup_key like 'auto-licence:%' and not exists(select 1 from public.customers c where c.id=e.entity_id and c.status='ACTIVE' and c.licence_expiry is not null and c.licence_expiry<=current_date+30);
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'COMPLIANCE_ATTENTION_REFRESHED','staff_profile',auth.uid(),jsonb_build_object('attention_items',n)); return n; end $$;

revoke all on function public.set_vehicle_service_interval(uuid,integer),public.create_maintenance_record(uuid,text,date,date,numeric,text),public.update_maintenance_record_status(uuid,text,text),public.complete_maintenance_record(uuid,integer,date,date,numeric,text),public.refresh_maintenance_compliance_attention() from public;
grant execute on function public.set_vehicle_service_interval(uuid,integer),public.create_maintenance_record(uuid,text,date,date,numeric,text),public.update_maintenance_record_status(uuid,text,text),public.complete_maintenance_record(uuid,integer,date,date,numeric,text),public.refresh_maintenance_compliance_attention() to authenticated;
