-- Authoritative customer approval, pickup/return readiness, compliance and maintenance.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED',
  'AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED',
  'PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED',
  'AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED',
  'EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED',
  'CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED',
  'COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED',
  'MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED'
));

alter table public.operational_exceptions drop constraint operational_exceptions_exception_type_check;
alter table public.operational_exceptions add constraint operational_exceptions_exception_type_check check (exception_type in (
  'OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','AGREEMENT_AWAITING_SIGNATURE','UNALLOCATED_FUNDS',
  'PAYMENT_ALLOCATION','SCHEDULE_EXTENSION_FAILURE','VEHICLE_SWAP_FAILURE','VEHICLE_STATE_INCONSISTENCY',
  'CUSTOMER_APPROVAL','PICKUP_PREREQUISITE','RETURN_PREREQUISITE','LICENCE_EXPIRY','REGISTRATION_EXPIRY',
  'RWC_EXPIRY','SERVICE_DUE','SERVICE_OVERDUE','VEHICLE_OFF_ROAD_TOO_LONG'
));

create table public.customer_approvals (
  customer_id uuid primary key references public.customers(id),
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED','SUSPENDED')),
  decided_by uuid references public.staff_profiles(user_id), decided_at timestamptz,
  reason_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check ((status='PENDING' and decided_by is null and decided_at is null) or (status<>'PENDING' and decided_by is not null and decided_at is not null))
);
create trigger customer_approvals_touch_updated_at before update on public.customer_approvals for each row execute function app_private.touch_updated_at();
insert into public.customer_approvals(customer_id) select id from public.customers on conflict do nothing;
create or replace function app_private.initialize_customer_approval() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.customer_approvals(customer_id) values(new.id) on conflict do nothing; return new; end; $$;
create trigger customers_initialize_approval after insert on public.customers for each row execute function app_private.initialize_customer_approval();

create table public.customer_documents (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id),
  document_type text not null check (document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS')),
  status text not null default 'MISSING' check (status in ('MISSING','SUBMITTED','VERIFIED','REJECTED','EXPIRED')),
  expiry_date date, verified_by uuid references public.staff_profiles(user_id), verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique(customer_id,document_type),
  check ((status='VERIFIED' and verified_by is not null and verified_at is not null) or status<>'VERIFIED')
);

create table public.vehicle_compliance (
  id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id),
  compliance_type text not null check (compliance_type in ('REGISTRATION','RWC')),
  status text not null default 'MISSING' check (status in ('VALID','EXPIRING_SOON','EXPIRED','MISSING')),
  issued_at date, expires_at date, verified_by uuid references public.staff_profiles(user_id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(vehicle_id,compliance_type), check (expires_at is null or issued_at is null or expires_at >= issued_at)
);
create trigger vehicle_compliance_touch_updated_at before update on public.vehicle_compliance for each row execute function app_private.touch_updated_at();

create table public.odometer_readings (
  id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id),
  odometer integer not null check (odometer>=0), reading_at timestamptz not null default now(),
  source text not null check (source in ('PICKUP','RETURN','SERVICE','MANUAL')), recorded_by uuid not null references public.staff_profiles(user_id),
  created_at timestamptz not null default now()
);
create index odometer_readings_vehicle_time on public.odometer_readings(vehicle_id,reading_at desc);

create table public.maintenance_plans (
  vehicle_id uuid primary key references public.vehicles(id), last_completed_service_odometer integer check(last_completed_service_odometer>=0),
  service_interval_km integer not null default 10000 check(service_interval_km>0),
  next_service_odometer integer generated always as (case when last_completed_service_odometer is null then null else last_completed_service_odometer+service_interval_km end) stored,
  status text not null default 'NOT_CONFIGURED' check(status in ('NOT_CONFIGURED','OK','DUE','OVERDUE','IN_SERVICE')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create trigger maintenance_plans_touch_updated_at before update on public.maintenance_plans for each row execute function app_private.touch_updated_at();

create table public.maintenance_jobs (
  id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id),
  status text not null default 'OPEN' check(status in ('OPEN','IN_PROGRESS','COMPLETED','CANCELLED')),
  opened_at timestamptz not null default now(), completed_at timestamptz, completion_odometer integer check(completion_odometer>=0),
  notes text, cost numeric(12,2) check(cost is null or cost>=0), opened_by uuid not null references public.staff_profiles(user_id),
  completed_by uuid references public.staff_profiles(user_id), created_at timestamptz not null default now(),
  check ((status='COMPLETED' and completed_at is not null and completion_odometer is not null and completed_by is not null) or status<>'COMPLETED')
);
create unique index maintenance_jobs_one_open_vehicle on public.maintenance_jobs(vehicle_id) where status in ('OPEN','IN_PROGRESS');

create table public.pickup_checklists (
  id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.agreements(id),
  customer_id uuid not null references public.customers(id), vehicle_id uuid not null references public.vehicles(id),
  status text not null default 'PREPARING' check(status in ('PREPARING','READY','COMPLETED','CANCELLED')),
  pickup_odometer integer check(pickup_odometer>=0), completed_by uuid references public.staff_profiles(user_id),
  completed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(agreement_id), check ((status='COMPLETED' and pickup_odometer is not null and completed_by is not null and completed_at is not null) or status<>'COMPLETED')
);
create trigger pickup_checklists_touch_updated_at before update on public.pickup_checklists for each row execute function app_private.touch_updated_at();

create table public.return_checklists (
  id uuid primary key default gen_random_uuid(), assignment_id uuid not null unique references public.vehicle_assignments(id),
  status text not null default 'PREPARING' check(status in ('PREPARING','READY','COMPLETED','CANCELLED')),
  return_odometer integer check(return_odometer>=0), return_condition text check(return_condition in ('GOOD','DAMAGE_NOTED','UNSAFE')),
  open_issue boolean not null default false, disposition text check(disposition in ('RELEASE','WORKSHOP','OFF_ROAD')),
  completed_by uuid references public.staff_profiles(user_id), completed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check ((status='COMPLETED' and return_odometer is not null and return_condition is not null and disposition is not null and completed_by is not null and completed_at is not null) or status<>'COMPLETED')
);
create trigger return_checklists_touch_updated_at before update on public.return_checklists for each row execute function app_private.touch_updated_at();

alter table public.vehicles add column operational_status_changed_at timestamptz not null default now();

create or replace function app_private.customer_is_ready(p_customer_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.customer_approvals where customer_id=p_customer_id and status='APPROVED')
 and not exists(select 1 from (values('DRIVER_LICENCE'),('PROOF_OF_ADDRESS')) r(t) where not exists(
   select 1 from public.customer_documents d where d.customer_id=p_customer_id and d.document_type=r.t and d.status='VERIFIED'
   and (d.expiry_date is null or d.expiry_date>=current_date)));
$$;
create or replace function app_private.vehicle_is_compliant(p_vehicle_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select not exists(select 1 from (values('REGISTRATION'),('RWC')) r(t) where not exists(
   select 1 from public.vehicle_compliance c where c.vehicle_id=p_vehicle_id and c.compliance_type=r.t
   and c.status in ('VALID','EXPIRING_SOON') and c.expires_at>=current_date));
$$;

create or replace view public.customer_readiness with (security_invoker=true) as
select c.id customer_id, coalesce(a.status,'PENDING') approval_status,
  exists(select 1 from public.customer_documents d where d.customer_id=c.id and d.document_type='DRIVER_LICENCE' and d.status='VERIFIED' and (d.expiry_date is null or d.expiry_date>=current_date)) licence_verified,
  exists(select 1 from public.customer_documents d where d.customer_id=c.id and d.document_type='PROOF_OF_ADDRESS' and d.status='VERIFIED' and (d.expiry_date is null or d.expiry_date>=current_date)) proof_of_address_verified,
  app_private.customer_is_ready(c.id) ready
from public.customers c left join public.customer_approvals a on a.customer_id=c.id;

create or replace view public.vehicle_maintenance_status with (security_invoker=true) as
select v.id vehicle_id,v.odometer,p.last_completed_service_odometer,p.service_interval_km,p.next_service_odometer,
 case when exists(select 1 from public.maintenance_jobs j where j.vehicle_id=v.id and j.status in ('OPEN','IN_PROGRESS')) then 'IN_SERVICE'
      when p.next_service_odometer is null then 'NOT_CONFIGURED'
      when v.odometer>=p.next_service_odometer+1000 then 'OVERDUE'
      when v.odometer>=p.next_service_odometer then 'DUE' else 'OK' end status
from public.vehicles v left join public.maintenance_plans p on p.vehicle_id=v.id;

alter table public.customer_approvals enable row level security; alter table public.customer_documents enable row level security;
alter table public.vehicle_compliance enable row level security; alter table public.odometer_readings enable row level security;
alter table public.maintenance_plans enable row level security; alter table public.maintenance_jobs enable row level security;
alter table public.pickup_checklists enable row level security; alter table public.return_checklists enable row level security;
create policy staff_read_customer_approvals on public.customer_approvals for select to authenticated using(app_private.is_staff());
create policy staff_read_customer_documents on public.customer_documents for select to authenticated using(app_private.is_staff());
create policy staff_read_vehicle_compliance on public.vehicle_compliance for select to authenticated using(app_private.is_staff());
create policy staff_read_odometer on public.odometer_readings for select to authenticated using(app_private.is_staff());
create policy staff_read_maintenance_plans on public.maintenance_plans for select to authenticated using(app_private.is_staff());
create policy staff_read_maintenance_jobs on public.maintenance_jobs for select to authenticated using(app_private.is_staff());
create policy staff_read_pickup on public.pickup_checklists for select to authenticated using(app_private.is_staff());
create policy staff_read_return on public.return_checklists for select to authenticated using(app_private.is_staff());
revoke all on public.customer_approvals,public.customer_documents,public.vehicle_compliance,public.odometer_readings,public.maintenance_plans,public.maintenance_jobs,public.pickup_checklists,public.return_checklists from anon,authenticated;
grant select on public.customer_approvals,public.customer_documents,public.vehicle_compliance,public.odometer_readings,public.maintenance_plans,public.maintenance_jobs,public.pickup_checklists,public.return_checklists,public.customer_readiness,public.vehicle_maintenance_status to authenticated;

create or replace function public.decide_customer_approval(p_customer_id uuid,p_status text,p_reason_notes text default null) returns public.customer_approvals language plpgsql security definer set search_path='' as $$
declare v public.customer_approvals; v_action text;
begin if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501'; end if;
 if p_status not in ('APPROVED','REJECTED','SUSPENDED') then raise exception 'invalid approval decision' using errcode='22023'; end if;
 insert into public.customer_approvals(customer_id,status,decided_by,decided_at,reason_notes) values(p_customer_id,p_status,auth.uid(),now(),nullif(btrim(p_reason_notes),''))
 on conflict(customer_id) do update set status=excluded.status,decided_by=excluded.decided_by,decided_at=excluded.decided_at,reason_notes=excluded.reason_notes returning * into v;
 v_action:=case p_status when 'APPROVED' then 'CUSTOMER_APPROVED' when 'REJECTED' then 'CUSTOMER_REJECTED' else 'CUSTOMER_SUSPENDED' end;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),v_action,'customer',p_customer_id,jsonb_build_object('status',p_status,'reason_notes',p_reason_notes)); return v; end; $$;

create or replace function public.set_customer_document(p_customer_id uuid,p_document_type text,p_status text,p_expiry_date date default null) returns public.customer_documents language plpgsql security definer set search_path='' as $$
declare v public.customer_documents;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_document_type not in ('DRIVER_LICENCE','PROOF_OF_ADDRESS') or p_status not in ('MISSING','SUBMITTED','VERIFIED','REJECTED','EXPIRED') then raise exception 'invalid document state' using errcode='22023'; end if;
 insert into public.customer_documents(customer_id,document_type,status,expiry_date,verified_by,verified_at) values(p_customer_id,p_document_type,p_status,p_expiry_date,case when p_status='VERIFIED' then auth.uid() end,case when p_status='VERIFIED' then now() end)
 on conflict(customer_id,document_type) do update set status=excluded.status,expiry_date=excluded.expiry_date,verified_by=excluded.verified_by,verified_at=excluded.verified_at returning * into v;
 if p_status in ('VERIFIED','REJECTED') then insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),case when p_status='VERIFIED' then 'DOCUMENT_VERIFIED' else 'DOCUMENT_REJECTED' end,'customer_document',v.id,jsonb_build_object('customer_id',p_customer_id,'document_type',p_document_type)); end if; return v; end; $$;

create or replace function public.set_vehicle_compliance(p_vehicle_id uuid,p_type text,p_status text,p_issued_at date,p_expires_at date) returns public.vehicle_compliance language plpgsql security definer set search_path='' as $$
declare v public.vehicle_compliance;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_type not in ('REGISTRATION','RWC') or p_status not in ('VALID','EXPIRING_SOON','EXPIRED','MISSING') then raise exception 'invalid compliance state' using errcode='22023'; end if;
 insert into public.vehicle_compliance(vehicle_id,compliance_type,status,issued_at,expires_at,verified_by) values(p_vehicle_id,p_type,p_status,p_issued_at,p_expires_at,auth.uid())
 on conflict(vehicle_id,compliance_type) do update set status=excluded.status,issued_at=excluded.issued_at,expires_at=excluded.expires_at,verified_by=excluded.verified_by returning * into v;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'COMPLIANCE_UPDATED','vehicle_compliance',v.id,jsonb_build_object('vehicle_id',p_vehicle_id,'type',p_type,'status',p_status,'expires_at',p_expires_at)); return v; end; $$;

create or replace function app_private.record_odometer(p_vehicle_id uuid,p_odometer integer,p_source text,p_reading_at timestamptz default now()) returns public.odometer_readings language plpgsql security definer set search_path='' as $$
declare v_vehicle public.vehicles; v public.odometer_readings;
begin select * into v_vehicle from public.vehicles where id=p_vehicle_id for update; if not found then raise exception 'vehicle not found'; end if;
 if p_odometer is null or p_odometer<v_vehicle.odometer then raise exception 'odometer cannot move backwards'; end if;
 insert into public.odometer_readings(vehicle_id,odometer,reading_at,source,recorded_by) values(p_vehicle_id,p_odometer,p_reading_at,p_source,auth.uid()) returning * into v;
 update public.vehicles set odometer=p_odometer where id=p_vehicle_id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'ODOMETER_RECORDED','odometer_reading',v.id,jsonb_build_object('vehicle_id',p_vehicle_id,'odometer',p_odometer,'source',p_source)); return v; end; $$;

create or replace function public.record_odometer(p_vehicle_id uuid,p_odometer integer,p_source text,p_reading_at timestamptz default now()) returns public.odometer_readings language plpgsql security definer set search_path='' as $$
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; return app_private.record_odometer(p_vehicle_id,p_odometer,p_source,p_reading_at); end; $$;

create or replace function public.open_maintenance_job(p_vehicle_id uuid,p_notes text default null,p_cost numeric default null) returns public.maintenance_jobs language plpgsql security definer set search_path='' as $$
declare v public.maintenance_jobs;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 insert into public.maintenance_plans(vehicle_id) values(p_vehicle_id) on conflict do nothing;
 insert into public.maintenance_jobs(vehicle_id,notes,cost,opened_by) values(p_vehicle_id,nullif(btrim(p_notes),''),p_cost,auth.uid()) returning * into v;
 update public.maintenance_plans set status='IN_SERVICE' where vehicle_id=p_vehicle_id; update public.vehicles set operational_status='WORKSHOP' where id=p_vehicle_id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'MAINTENANCE_JOB_OPENED','maintenance_job',v.id,jsonb_build_object('vehicle_id',p_vehicle_id)); return v; end; $$;

create or replace function public.complete_maintenance_job(p_job_id uuid,p_odometer integer,p_notes text default null,p_cost numeric default null) returns public.maintenance_jobs language plpgsql security definer set search_path='' as $$
declare v public.maintenance_jobs;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into v from public.maintenance_jobs where id=p_job_id and status in ('OPEN','IN_PROGRESS') for update; if not found then raise exception 'open maintenance job not found'; end if;
 perform app_private.record_odometer(v.vehicle_id,p_odometer,'SERVICE',now());
 update public.maintenance_jobs set status='COMPLETED',completed_at=now(),completion_odometer=p_odometer,completed_by=auth.uid(),notes=coalesce(nullif(btrim(p_notes),''),notes),cost=coalesce(p_cost,cost) where id=p_job_id returning * into v;
 insert into public.maintenance_plans(vehicle_id,last_completed_service_odometer,status) values(v.vehicle_id,p_odometer,'OK') on conflict(vehicle_id) do update set last_completed_service_odometer=excluded.last_completed_service_odometer,status='OK';
 update public.vehicles set operational_status='AVAILABLE' where id=v.vehicle_id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'MAINTENANCE_JOB_COMPLETED','maintenance_job',v.id,jsonb_build_object('vehicle_id',v.vehicle_id,'odometer',p_odometer)); return v; end; $$;

create or replace function public.create_pickup_checklist(p_agreement_id uuid) returns public.pickup_checklists language plpgsql security definer set search_path='' as $$
declare a public.agreements; v public.pickup_checklists;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into a from public.agreements where id=p_agreement_id; if not found or a.customer_id is null or a.vehicle_id is null then raise exception 'agreement customer and vehicle required'; end if;
 insert into public.pickup_checklists(agreement_id,customer_id,vehicle_id) values(a.id,a.customer_id,a.vehicle_id) on conflict(agreement_id) do update set updated_at=now() returning * into v; return v; end; $$;

create or replace function public.complete_pickup(p_checklist_id uuid,p_odometer integer) returns public.vehicle_assignments language plpgsql security definer set search_path='' as $$
declare c public.pickup_checklists; a public.agreements; v public.vehicle_assignments; ve public.vehicles;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into c from public.pickup_checklists where id=p_checklist_id and status<>'COMPLETED' for update; if not found then raise exception 'open pickup checklist not found'; end if;
 select * into a from public.agreements where id=c.agreement_id for update; select * into ve from public.vehicles where id=c.vehicle_id for update;
 if a.status not in ('PENDING_SIGNATURE','ACTIVE') then raise exception 'agreement is not ready'; end if; if not app_private.customer_is_ready(c.customer_id) then raise exception 'customer prerequisites are incomplete'; end if;
 if not app_private.vehicle_is_compliant(c.vehicle_id) then raise exception 'vehicle compliance is incomplete or expired'; end if; if ve.operational_status not in ('AVAILABLE','PICKUP_PENDING') then raise exception 'vehicle is not available'; end if;
 perform app_private.record_odometer(c.vehicle_id,p_odometer,'PICKUP',now()); insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values(c.customer_id,c.vehicle_id,now(),p_odometer,'ACTIVE',auth.uid()) returning * into v;
 update public.vehicles set operational_status='ASSIGNED' where id=c.vehicle_id; update public.pickup_checklists set status='COMPLETED',pickup_odometer=p_odometer,completed_by=auth.uid(),completed_at=now() where id=c.id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PICKUP_COMPLETED','pickup_checklist',c.id,jsonb_build_object('assignment_id',v.id,'agreement_id',a.id)); return v; end; $$;

create or replace function public.create_return_checklist(p_assignment_id uuid) returns public.return_checklists language plpgsql security definer set search_path='' as $$
declare v public.return_checklists; begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if not exists(select 1 from public.vehicle_assignments where id=p_assignment_id and assignment_status='ACTIVE') then raise exception 'active assignment not found'; end if;
 insert into public.return_checklists(assignment_id) values(p_assignment_id) on conflict(assignment_id) do update set updated_at=now() returning * into v; return v; end; $$;

create or replace function public.complete_return(p_checklist_id uuid,p_odometer integer,p_condition text,p_open_issue boolean,p_disposition text) returns public.vehicle_assignments language plpgsql security definer set search_path='' as $$
declare c public.return_checklists; a public.vehicle_assignments; target text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_condition not in ('GOOD','DAMAGE_NOTED','UNSAFE') or p_disposition not in ('RELEASE','WORKSHOP','OFF_ROAD') then raise exception 'invalid return state'; end if;
 select * into c from public.return_checklists where id=p_checklist_id and status<>'COMPLETED' for update; if not found then raise exception 'open return checklist not found'; end if; select * into a from public.vehicle_assignments where id=c.assignment_id and assignment_status='ACTIVE' for update; if not found then raise exception 'active assignment not found'; end if;
 if exists(select 1 from public.agreements g where g.customer_id=a.customer_id and g.vehicle_id=a.vehicle_id and g.status='ACTIVE') then raise exception 'active agreement must be closed before return'; end if;
 perform app_private.record_odometer(a.vehicle_id,p_odometer,'RETURN',now()); update public.vehicle_assignments set assignment_status='RETURNED',returned_at=greatest(now(),a.assigned_at+interval '1 microsecond'),return_odometer=p_odometer where id=a.id returning * into a;
 target:=case p_disposition when 'RELEASE' then 'AVAILABLE' else p_disposition end; update public.vehicles set operational_status=target where id=a.vehicle_id;
 update public.return_checklists set status='COMPLETED',return_odometer=p_odometer,return_condition=p_condition,open_issue=coalesce(p_open_issue,false),disposition=p_disposition,completed_by=auth.uid(),completed_at=now() where id=c.id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'RETURN_COMPLETED','return_checklist',c.id,jsonb_build_object('assignment_id',a.id,'condition',p_condition,'open_issue',p_open_issue,'disposition',p_disposition)); return a; end; $$;

create or replace function app_private.track_vehicle_workshop_state() returns trigger language plpgsql security definer set search_path='' as $$
begin if old.operational_status is distinct from new.operational_status then new.operational_status_changed_at:=now(); if old.operational_status in ('WORKSHOP','OFF_ROAD') or new.operational_status in ('WORKSHOP','OFF_ROAD') then insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'VEHICLE_WORKSHOP_STATE_CHANGED','vehicle',new.id,jsonb_build_object('from',old.operational_status,'to',new.operational_status)); end if; end if; return new; end; $$;
create trigger vehicles_track_workshop_state before update of operational_status on public.vehicles for each row execute function app_private.track_vehicle_workshop_state();

create or replace function public.refresh_readiness_exceptions(p_expiring_days integer default 30,p_offroad_days integer default 7) returns integer language plpgsql security definer set search_path='' as $$
declare v record; n integer:=0; sev text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 for v in select c.id,c.full_name from public.customers c left join public.customer_approvals a on a.customer_id=c.id where coalesce(a.status,'PENDING')='PENDING' loop perform app_private.upsert_exception('CUSTOMER_APPROVAL','MEDIUM','customer',v.id,'customer-approval:'||v.id,'Customer approval awaiting Veera','{}',true,auth.uid()); n:=n+1; end loop;
 for v in select p.id from public.pickup_checklists p where p.status<>'COMPLETED' and (not app_private.customer_is_ready(p.customer_id) or not app_private.vehicle_is_compliant(p.vehicle_id) or not exists(select 1 from public.agreements a where a.id=p.agreement_id and a.status in ('PENDING_SIGNATURE','ACTIVE'))) loop perform app_private.upsert_exception('PICKUP_PREREQUISITE','HIGH','pickup_checklist',v.id,'pickup:'||v.id,'Pickup blocked by missing prerequisites','{}',false,auth.uid()); n:=n+1; end loop;
 for v in select r.id from public.return_checklists r join public.vehicle_assignments a on a.id=r.assignment_id where r.status<>'COMPLETED' and a.assignment_status='ACTIVE' loop perform app_private.upsert_exception('RETURN_PREREQUISITE','MEDIUM','return_checklist',v.id,'return:'||v.id,'Return checklist incomplete','{}',false,auth.uid()); n:=n+1; end loop;
 for v in select d.id,d.customer_id,d.expiry_date from public.customer_documents d where d.document_type='DRIVER_LICENCE' and d.expiry_date<=current_date+p_expiring_days loop sev:=case when v.expiry_date<current_date then 'HIGH' else 'MEDIUM' end; perform app_private.upsert_exception('LICENCE_EXPIRY',sev,'customer',v.customer_id,'licence:'||v.customer_id,case when v.expiry_date<current_date then 'Driver licence expired' else 'Driver licence expiring soon' end,jsonb_build_object('expires_at',v.expiry_date),false,auth.uid()); n:=n+1; end loop;
 for v in select c.* from public.vehicle_compliance c where c.expires_at<=current_date+p_expiring_days loop sev:=case when v.expires_at<current_date then 'HIGH' else 'MEDIUM' end; perform app_private.upsert_exception(case v.compliance_type when 'REGISTRATION' then 'REGISTRATION_EXPIRY' else 'RWC_EXPIRY' end,sev,'vehicle',v.vehicle_id,lower(v.compliance_type)||':'||v.vehicle_id,case when v.expires_at<current_date then v.compliance_type||' expired' else v.compliance_type||' expiring soon' end,jsonb_build_object('expires_at',v.expires_at),false,auth.uid()); n:=n+1; end loop;
 for v in select * from public.vehicle_maintenance_status where status in ('DUE','OVERDUE') loop perform app_private.upsert_exception(case v.status when 'DUE' then 'SERVICE_DUE' else 'SERVICE_OVERDUE' end,case v.status when 'DUE' then 'MEDIUM' else 'HIGH' end,'vehicle',v.vehicle_id,'service:'||v.vehicle_id,'Vehicle service '||lower(v.status),jsonb_build_object('odometer',v.odometer,'next_service_odometer',v.next_service_odometer),false,auth.uid()); n:=n+1; end loop;
 for v in select id,operational_status,operational_status_changed_at from public.vehicles where operational_status in ('WORKSHOP','OFF_ROAD') and operational_status_changed_at<now()-(p_offroad_days||' days')::interval loop perform app_private.upsert_exception('VEHICLE_OFF_ROAD_TOO_LONG','HIGH','vehicle',v.id,'offroad:'||v.id,'Vehicle has been off-road too long',jsonb_build_object('since',v.operational_status_changed_at,'status',v.operational_status),true,auth.uid()); n:=n+1; end loop; return n; end; $$;

revoke all on function public.decide_customer_approval(uuid,text,text),public.set_customer_document(uuid,text,text,date),public.set_vehicle_compliance(uuid,text,text,date,date),public.record_odometer(uuid,integer,text,timestamptz),public.open_maintenance_job(uuid,text,numeric),public.complete_maintenance_job(uuid,integer,text,numeric),public.create_pickup_checklist(uuid),public.complete_pickup(uuid,integer),public.create_return_checklist(uuid),public.complete_return(uuid,integer,text,boolean,text),public.refresh_readiness_exceptions(integer,integer) from public;
grant execute on function public.decide_customer_approval(uuid,text,text),public.set_customer_document(uuid,text,text,date),public.set_vehicle_compliance(uuid,text,text,date,date),public.record_odometer(uuid,integer,text,timestamptz),public.open_maintenance_job(uuid,text,numeric),public.complete_maintenance_job(uuid,integer,text,numeric),public.create_pickup_checklist(uuid),public.complete_pickup(uuid,integer),public.create_return_checklist(uuid),public.complete_return(uuid,integer,text,boolean,text),public.refresh_readiness_exceptions(integer,integer) to authenticated;

-- Existing assignment API remains callable for compatibility, but cannot bypass readiness.
create or replace function public.assign_vehicle_to_customer(p_customer_id uuid,p_vehicle_id uuid,p_pickup_odometer integer,p_assigned_at timestamptz default now()) returns public.vehicle_assignments language plpgsql security definer set search_path='' as $$
declare v_vehicle public.vehicles; v_assignment public.vehicle_assignments;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if not app_private.customer_is_ready(p_customer_id) then raise exception 'customer prerequisites are incomplete'; end if; if not app_private.vehicle_is_compliant(p_vehicle_id) then raise exception 'vehicle compliance is incomplete or expired'; end if;
 select * into v_vehicle from public.vehicles where id=p_vehicle_id for update; if not found then raise exception 'vehicle not found'; end if; if v_vehicle.operational_status not in ('AVAILABLE','PICKUP_PENDING') then raise exception 'vehicle is not available'; end if;
 perform app_private.record_odometer(p_vehicle_id,p_pickup_odometer,'PICKUP',p_assigned_at); insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by) values(p_customer_id,p_vehicle_id,p_assigned_at,p_pickup_odometer,'ACTIVE',auth.uid()) returning * into v_assignment; update public.vehicles set operational_status='ASSIGNED' where id=p_vehicle_id;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'ASSIGNMENT_CREATED','vehicle_assignment',v_assignment.id,jsonb_build_object('customer_id',p_customer_id,'vehicle_id',p_vehicle_id)); return v_assignment; end; $$;
