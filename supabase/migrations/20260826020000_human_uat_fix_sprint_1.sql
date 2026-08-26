-- Human UAT fix sprint 1: safe access lifecycle and physical custody boundaries.

alter table public.pickup_checklists
  add column handover_confirmed boolean not null default false;

create or replace function public.change_account_access(
  p_user_id uuid,
  p_account_type text,
  p_enabled boolean
) returns text
language plpgsql security definer set search_path=''
as $$
declare
  changed integer;
  customer_id uuid;
  result text;
begin
  if not app_private.is_admin() then
    raise exception 'administrator access required' using errcode='42501';
  end if;
  if p_account_type not in ('STAFF','CUSTOMER') then
    raise exception 'invalid account type' using errcode='22023';
  end if;
  if p_user_id=auth.uid() and p_account_type='STAFF' and not p_enabled then
    raise exception 'you cannot disable your own administrator account' using errcode='22023';
  end if;

  if p_account_type='CUSTOMER' then
    update public.customer_portal_accounts
      set status=case when p_enabled then 'ACTIVE' else 'DISABLED' end
      where user_id=p_user_id
      returning customer_portal_accounts.customer_id into customer_id;
    get diagnostics changed=row_count;
    if changed=0 then raise exception 'customer portal account not found'; end if;
    insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
      values(auth.uid(),'CUSTOMER_PORTAL_ACCESS_CHANGED','customer',customer_id,
        jsonb_build_object('portal_user_id',p_user_id,'enabled',p_enabled));
  else
    update public.staff_profiles
      set status=case when p_enabled then 'ACTIVE' else 'DISABLED' end,is_active=p_enabled
      where user_id=p_user_id;
    get diagnostics changed=row_count;
    if changed=0 then raise exception 'staff account not found'; end if;
    insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
      values(auth.uid(),'STAFF_ACCESS_CHANGED','staff_profile',p_user_id,
        jsonb_build_object('enabled',p_enabled));
  end if;

  result:=case when p_enabled then 'ENABLED' else 'DISABLED' end;
  insert into public.account_security_events(actor,subject_user_id,event_type,context)
    values(auth.uid(),p_user_id,case when p_enabled then 'ACCOUNT_ENABLED' else 'ACCOUNT_DISABLED' end,
      jsonb_build_object('account_type',p_account_type));
  if not p_enabled then
    insert into public.account_security_events(actor,subject_user_id,event_type,context)
      values(auth.uid(),p_user_id,'SESSIONS_REVOKED',jsonb_build_object('method','AUTH_BAN'));
  end if;
  return result;
end $$;

notify pgrst,'reload schema';

revoke all on function public.change_account_access(uuid,text,boolean) from public,anon;
grant execute on function public.change_account_access(uuid,text,boolean) to authenticated;

create or replace function public.set_customer_portal_access(p_user_id uuid,p_customer_id uuid,p_enabled boolean)
returns public.customer_portal_accounts language plpgsql security definer set search_path=''
as $$
declare r public.customer_portal_accounts;
begin
  if not app_private.is_admin() then raise exception 'administrator access required' using errcode='42501';end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'authentication user not found';end if;
  if not exists(select 1 from public.customers where id=p_customer_id) then raise exception 'customer not found';end if;
  insert into public.customer_portal_accounts(user_id,customer_id,status,created_by)
    values(p_user_id,p_customer_id,case when p_enabled then 'ACTIVE' else 'DISABLED' end,auth.uid())
    on conflict(user_id) do update set customer_id=excluded.customer_id,status=excluded.status,created_by=excluded.created_by returning * into r;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
    values(auth.uid(),'CUSTOMER_PORTAL_ACCESS_CHANGED','customer',p_customer_id,jsonb_build_object('portal_user_id',p_user_id,'enabled',p_enabled));
  insert into public.account_security_events(actor,subject_user_id,event_type,context)
    values(auth.uid(),p_user_id,case when p_enabled then 'ACCOUNT_ENABLED' else 'ACCOUNT_DISABLED' end,jsonb_build_object('account_type','CUSTOMER'));
  if not p_enabled then insert into public.account_security_events(actor,subject_user_id,event_type,context)
    values(auth.uid(),p_user_id,'SESSIONS_REVOKED',jsonb_build_object('method','AUTH_BAN'));end if;
  return r;
end $$;

-- Planning a customer/vehicle relationship is represented by the agreement and
-- pickup checklist. A custody row is created only by successful handover.
create or replace function public.assign_vehicle_to_customer(
  p_customer_id uuid,p_vehicle_id uuid,p_pickup_odometer integer,p_assigned_at timestamptz default now()
)
returns public.vehicle_assignments
language plpgsql security definer set search_path=''
as $$
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
  perform p_customer_id,p_vehicle_id,p_pickup_odometer,p_assigned_at;
  raise exception 'direct custody assignment is disabled; schedule and complete a pickup handover' using errcode='55000';
end $$;

create or replace function public.transition_agreement(
  p_agreement_id uuid,p_new_status text,p_signed_at timestamptz default null
) returns public.agreements
language plpgsql security definer set search_path=''
as $$
declare v_before public.agreements;v_after public.agreements;v_action text;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;
  select * into v_before from public.agreements where id=p_agreement_id for update;
  if not found then raise exception 'agreement not found';end if;
  if not ((v_before.status='DRAFT' and p_new_status in('PENDING_SIGNATURE','CANCELLED'))
    or (v_before.status='PENDING_SIGNATURE' and p_new_status in('ACTIVE','CANCELLED'))
    or (v_before.status='ACTIVE' and p_new_status in('SUSPENDED','COMPLETED','CANCELLED'))
    or (v_before.status='SUSPENDED' and p_new_status in('ACTIVE','COMPLETED','CANCELLED'))) then
    raise exception 'invalid agreement status transition';
  end if;
  if p_new_status='ACTIVE' then
    if v_before.customer_id is null or v_before.vehicle_id is null then raise exception 'active agreement requires customer and vehicle';end if;
    if not exists(select 1 from public.pickup_checklists p where p.agreement_id=v_before.id and p.status not in('COMPLETED','CANCELLED'))
       and not exists(select 1 from public.vehicle_assignments va where va.customer_id=v_before.customer_id and va.vehicle_id=v_before.vehicle_id and va.assignment_status='ACTIVE') then
      raise exception 'schedule the pickup before activating the agreement';
    end if;
    if exists(select 1 from public.agreements a where a.vehicle_id=v_before.vehicle_id and a.status='ACTIVE' and a.id<>v_before.id) then
      raise exception 'vehicle already has an active agreement';
    end if;
  end if;
  update public.agreements set status=p_new_status,
    signed_at=case when p_new_status='ACTIVE' then coalesce(p_signed_at,signed_at,now()) else signed_at end
    where id=p_agreement_id returning * into v_after;
  v_action:=case p_new_status when 'ACTIVE' then 'AGREEMENT_ACTIVATED' when 'SUSPENDED' then 'AGREEMENT_SUSPENDED' when 'COMPLETED' then 'AGREEMENT_COMPLETED' when 'CANCELLED' then 'AGREEMENT_CANCELLED' else null end;
  if v_action is not null then insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),v_action,'agreement',v_after.id,jsonb_build_object('from',v_before.status,'to',p_new_status));end if;
  if p_new_status='ACTIVE' then perform public.generate_payment_schedule(p_agreement_id,null);end if;
  return v_after;
end $$;

create or replace function public.complete_pickup(
  p_checklist_id uuid,p_odometer integer,p_actual_at timestamptz,p_handover_confirmed boolean
) returns public.vehicle_assignments
language plpgsql security definer set search_path=''
as $$
declare c public.pickup_checklists;a public.agreements;v public.vehicle_assignments;ve public.vehicles;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;
  if not coalesce(p_handover_confirmed,false) then raise exception 'confirm that keys and vehicle were handed over';end if;
  if p_actual_at is null or p_actual_at>now()+interval '5 minutes' then raise exception 'invalid handover time';end if;
  select * into c from public.pickup_checklists where id=p_checklist_id and status not in('COMPLETED','CANCELLED') for update;
  if not found then raise exception 'open pickup checklist not found';end if;
  select * into a from public.agreements where id=c.agreement_id for update;
  select * into ve from public.vehicles where id=c.vehicle_id for update;
  if a.status<>'ACTIVE' then raise exception 'agreement must be active before pickup';end if;
  if app_private.vehicle_has_blocking_issue(c.vehicle_id) then raise exception 'vehicle has an unresolved blocking issue';end if;
  if not app_private.customer_is_ready(c.customer_id) then raise exception 'customer approval or required documents are incomplete';end if;
  if not app_private.vehicle_is_compliant(c.vehicle_id) then raise exception 'vehicle registration or RWC is incomplete or expired';end if;
  if exists(select 1 from public.vehicle_maintenance_status m where m.vehicle_id=c.vehicle_id and m.status in('OVERDUE','IN_PROGRESS')) then raise exception 'vehicle maintenance blocks pickup';end if;
  if ve.operational_status not in('AVAILABLE','PICKUP_PENDING') then raise exception 'vehicle is not available for pickup';end if;
  perform app_private.record_odometer(c.vehicle_id,p_odometer,'PICKUP',p_actual_at);
  insert into public.vehicle_assignments(customer_id,vehicle_id,assigned_at,pickup_odometer,assignment_status,created_by)
    values(c.customer_id,c.vehicle_id,p_actual_at,p_odometer,'ACTIVE',auth.uid()) returning * into v;
  update public.vehicles set operational_status='ASSIGNED' where id=c.vehicle_id;
  update public.pickup_checklists set status='COMPLETED',pickup_odometer=p_odometer,handover_confirmed=true,
    completed_by=auth.uid(),completed_at=now(),actual_at=p_actual_at where id=c.id;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
    values(auth.uid(),'PICKUP_COMPLETED','pickup_checklist',c.id,jsonb_build_object('assignment_id',v.id,'agreement_id',a.id,'actual_at',p_actual_at,'handover_confirmed',true));
  return v;
end $$;

revoke all on function public.complete_pickup(uuid,integer,timestamptz,boolean) from public,anon;
grant execute on function public.complete_pickup(uuid,integer,timestamptz,boolean) to authenticated;

-- Compatibility for trusted callers during the migration window. The durable UI
-- uses the explicit handover signature above; this wrapper still creates custody
-- only through the same readiness-checked pickup completion transaction.
create or replace function public.complete_pickup(p_checklist_id uuid,p_odometer integer)
returns public.vehicle_assignments
language sql security definer set search_path=''
as $$ select public.complete_pickup(p_checklist_id,p_odometer,now(),true) $$;

create or replace function public.complete_return(p_checklist_id uuid,p_odometer integer,p_condition text,p_open_issue boolean,p_disposition text)
returns public.vehicle_assignments
language plpgsql security definer set search_path=''
as $$
declare c public.return_checklists;a public.vehicle_assignments;target text;derived_disposition text;
begin
  if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;
  perform p_disposition; -- retained only for backwards-compatible function identity; result is derived below.
  if p_condition not in('GOOD','DAMAGE_NOTED','UNSAFE') then raise exception 'invalid return condition' using errcode='22023';end if;
  select * into c from public.return_checklists where id=p_checklist_id and status not in('COMPLETED','CANCELLED') for update;
  if not found then raise exception 'open return checklist not found';end if;
  select * into a from public.vehicle_assignments where id=c.assignment_id and assignment_status='ACTIVE' for update;
  if not found then raise exception 'active custody record not found';end if;
  perform app_private.record_odometer(a.vehicle_id,p_odometer,'RETURN',now());
  perform set_config('app.return_workflow','on',true);
  update public.vehicle_assignments set assignment_status='RETURNED',returned_at=greatest(now(),a.assigned_at+interval '1 microsecond'),return_odometer=p_odometer where id=a.id returning * into a;
  if exists(select 1 from public.maintenance_service_records m where m.vehicle_id=a.vehicle_id and m.status in('SCHEDULED','IN_PROGRESS'))
     or exists(select 1 from public.maintenance_jobs m where m.vehicle_id=a.vehicle_id and m.status in('OPEN','IN_PROGRESS')) then
    target:='WORKSHOP';derived_disposition:='WORKSHOP';
  elsif p_condition<>'GOOD' or coalesce(p_open_issue,false) or app_private.vehicle_has_blocking_issue(a.vehicle_id)
     or exists(select 1 from public.agreements g where g.vehicle_id=a.vehicle_id and g.status in('ACTIVE','SUSPENDED'))
     or not app_private.vehicle_is_compliant(a.vehicle_id)
     or exists(select 1 from public.vehicle_maintenance_status m where m.vehicle_id=a.vehicle_id and m.status='OVERDUE') then
    target:='OFF_ROAD';derived_disposition:='OFF_ROAD';
  else target:='AVAILABLE';derived_disposition:='RELEASE';end if;
  update public.vehicles set operational_status=target where id=a.vehicle_id;
  update public.return_checklists set status='COMPLETED',return_odometer=p_odometer,return_condition=p_condition,
    open_issue=coalesce(p_open_issue,false),disposition=derived_disposition,completed_by=auth.uid(),completed_at=now(),actual_at=now() where id=c.id;
  insert into public.audit_events(actor,action,entity_type,entity_id,metadata)
    values(auth.uid(),'RETURN_COMPLETED','return_checklist',c.id,jsonb_build_object('assignment_id',a.id,'condition',p_condition,'open_issue',p_open_issue,'resulting_vehicle_status',target));
  return a;
end $$;

create or replace function app_private.protect_active_agreement_assignment()
returns trigger language plpgsql set search_path=''
as $$
begin
  if old.assignment_status='ACTIVE' and new.assignment_status='RETURNED'
    and coalesce(current_setting('app.return_workflow',true),'')<>'on'
    and exists(select 1 from public.agreements a where a.vehicle_id=old.vehicle_id and a.customer_id=old.customer_id and a.status='ACTIVE') then
    raise exception 'active agreement must be suspended, completed, or cancelled before assignment closes';
  end if;
  return new;
end $$;
