-- Controlled rent-to-own completion. This records staff confirmation of an
-- external/legal transfer; Veera never performs or assumes the transfer.

create table public.rto_ownership_transfer_confirmations (
  agreement_id uuid primary key references public.agreements(id),
  confirmed_by uuid not null references public.staff_profiles(user_id),
  confirmed_at timestamptz not null default now(),
  external_reference text not null check(btrim(external_reference)<>'' and length(external_reference)<=255),
  confirmation_note text not null check(btrim(confirmation_note)<>'' and length(confirmation_note)<=1000),
  created_at timestamptz not null default now()
);

create or replace function app_private.reject_rto_confirmation_mutation()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'ownership transfer confirmation history is immutable' using errcode='42501'; end $$;
create trigger rto_confirmation_immutable before update or delete on public.rto_ownership_transfer_confirmations
for each row execute function app_private.reject_rto_confirmation_mutation();

alter table public.rto_ownership_transfer_confirmations enable row level security;
create policy staff_read_rto_confirmations on public.rto_ownership_transfer_confirmations
for select to authenticated using(app_private.is_staff());
revoke all on public.rto_ownership_transfer_confirmations from anon,authenticated;
grant select on public.rto_ownership_transfer_confirmations to authenticated;

create or replace function public.confirm_rto_ownership_transfer(p_agreement_id uuid,p_external_reference text,p_confirmation_note text)
returns public.rto_ownership_transfer_confirmations language plpgsql security definer set search_path='' as $$
declare a public.agreements;r public.rto_ownership_transfer_confirmations;
begin
 if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501';end if;
 select * into a from public.agreements where id=p_agreement_id for update;
 if not found or a.agreement_type<>'RENT_TO_OWN' then raise exception 'rent-to-own agreement not found';end if;
 if a.status not in('ACTIVE','SUSPENDED') then raise exception 'agreement is not ready for completion';end if;
 if btrim(coalesce(p_external_reference,''))='' or btrim(coalesce(p_confirmation_note,''))='' then raise exception 'external transfer reference and confirmation note are required' using errcode='22023';end if;
 if exists(select 1 from public.payment_schedule_items s where s.agreement_id=a.id and s.status<>'WAIVED' and s.amount_paid<s.amount_due) then raise exception 'contractual payment schedule is not complete';end if;
 if a.agreed_payment_count is not null and (select count(*) from public.payment_schedule_items s where s.agreement_id=a.id and s.status<>'WAIVED')<a.agreed_payment_count then raise exception 'stored contractual payment count is not fully scheduled';end if;
 if a.agreed_total_amount is not null and (select coalesce(sum(s.amount_due),0) from public.payment_schedule_items s where s.agreement_id=a.id and s.status<>'WAIVED')<a.agreed_total_amount then raise exception 'stored contractual total is not fully scheduled';end if;
 insert into public.rto_ownership_transfer_confirmations(agreement_id,confirmed_by,external_reference,confirmation_note)
 values(a.id,auth.uid(),btrim(p_external_reference),btrim(p_confirmation_note)) returning * into r;
 return r;
end $$;

create or replace view public.rent_to_own_completion_readiness with(security_invoker=true) as
select a.id agreement_id,a.status agreement_status,a.agreed_total_amount,a.agreed_payment_count,a.weekly_amount,
 count(s.id) filter(where s.status<>'WAIVED') scheduled_payments,
 count(s.id) filter(where s.status='PAID') payments_completed,
 coalesce(sum(s.amount_paid),0)::numeric(12,2) amount_paid,
 greatest(0,coalesce(a.agreed_total_amount,sum(s.amount_due))-coalesce(sum(s.amount_paid),0))::numeric(12,2) remaining_contractual_balance,
 (not exists(select 1 from public.payment_schedule_items x where x.agreement_id=a.id and x.status<>'WAIVED' and x.amount_paid<x.amount_due)
  and (a.agreed_payment_count is null or count(s.id) filter(where s.status<>'WAIVED')>=a.agreed_payment_count)
  and (a.agreed_total_amount is null or coalesce(sum(s.amount_due) filter(where s.status<>'WAIVED'),0)>=a.agreed_total_amount)) payment_schedule_complete,
 c.confirmed_at is not null external_transfer_confirmed,c.confirmed_at,c.external_reference,
 (not exists(select 1 from public.payment_schedule_items x where x.agreement_id=a.id and x.status<>'WAIVED' and x.amount_paid<x.amount_due)
  and (a.agreed_payment_count is null or count(s.id) filter(where s.status<>'WAIVED')>=a.agreed_payment_count)
  and (a.agreed_total_amount is null or coalesce(sum(s.amount_due) filter(where s.status<>'WAIVED'),0)>=a.agreed_total_amount)
  and c.confirmed_at is not null) ready_to_complete
from public.agreements a left join public.payment_schedule_items s on s.agreement_id=a.id
left join public.rto_ownership_transfer_confirmations c on c.agreement_id=a.id
where a.agreement_type='RENT_TO_OWN'
group by a.id,c.confirmed_at,c.external_reference;
grant select on public.rent_to_own_completion_readiness to authenticated;

-- Preserve the existing lifecycle and add only the RTO completion guard.
create or replace function app_private.rto_completion_allowed(p_agreement_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.rto_ownership_transfer_confirmations c where c.agreement_id=p_agreement_id)
 and not exists(select 1 from public.payment_schedule_items s where s.agreement_id=p_agreement_id and s.status<>'WAIVED' and s.amount_paid<s.amount_due)
 and not exists(select 1 from public.agreements a where a.id=p_agreement_id and ((a.agreed_payment_count is not null and (select count(*) from public.payment_schedule_items s where s.agreement_id=a.id and s.status<>'WAIVED')<a.agreed_payment_count) or (a.agreed_total_amount is not null and (select coalesce(sum(s.amount_due),0) from public.payment_schedule_items s where s.agreement_id=a.id and s.status<>'WAIVED')<a.agreed_total_amount)))
$$;

create or replace function app_private.guard_rto_completion()
returns trigger language plpgsql set search_path='' as $$
begin
 if old.agreement_type='RENT_TO_OWN' and new.status='COMPLETED' and old.status<>new.status
   and not app_private.rto_completion_allowed(old.id) then
   raise exception 'rent-to-own completion requires paid schedule and confirmed external ownership transfer';
 end if;
 return new;
end $$;
create trigger agreements_guard_rto_completion before update of status on public.agreements
for each row execute function app_private.guard_rto_completion();

revoke all on function public.confirm_rto_ownership_transfer(uuid,text,text) from public;
grant execute on function public.confirm_rto_ownership_transfer(uuid,text,text) to authenticated;

create or replace function public.daily_operations_snapshot() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;
 return jsonb_build_object(
  'pickups',(select count(*) from public.pickup_checklists where status not in('COMPLETED','CANCELLED') and scheduled_at::date=current_date),
  'returns',(select count(*) from public.return_checklists where status not in('COMPLETED','CANCELLED') and scheduled_at::date=current_date),
  'overdue_payments',(select count(*) from public.payment_schedule_items where status<>'WAIVED' and amount_paid<amount_due and due_date<current_date),
  'vehicles_ready',(select count(*) from public.fleet_operations where ready_for_allocation),
  'vehicles_blocked',(select count(*) from public.fleet_operations where operational_status='AVAILABLE' and not ready_for_allocation),
  'maintenance_due',(select count(*) from public.vehicle_maintenance_status where status in('DUE_SOON','OVERDUE')),
  'customer_approvals',(select count(*) from public.customer_approvals where status='PENDING'),
  'critical_issues',(select count(*) from public.vehicle_issues where status not in('RESOLVED','CANCELLED') and severity in('CRITICAL','HIGH')),
  'portal_requests',(select count(*) from public.customer_portal_requests where status in('SUBMITTED','IN_REVIEW')),
  'document_reviews',(select count(*) from public.document_versions where status in('SUBMITTED','PENDING_REVIEW'))
 );
end $$;

create or replace function public.management_report_snapshot() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;
 return jsonb_build_object(
  'fleet',jsonb_build_object('total',(select count(*) from public.vehicles),'available',(select count(*) from public.vehicles where operational_status='AVAILABLE'),'rented',(select count(*) from public.vehicles where operational_status='ASSIGNED'),'workshop',(select count(*) from public.vehicles where operational_status='WORKSHOP'),'off_road',(select count(*) from public.vehicles where operational_status='OFF_ROAD')),
  'finance',jsonb_build_object('expected_this_week',(select coalesce(sum(amount_due),0) from public.payment_schedule_items where due_date between current_date-date_part('dow',current_date)::int and current_date-date_part('dow',current_date)::int+6),'received_this_week',(select coalesce(sum(amount),0) from public.payment_transactions where transaction_type='RECEIPT' and received_at>=date_trunc('week',now())),'overdue',(select coalesce(sum(amount_due-amount_paid),0) from public.payment_schedule_items where due_date<current_date and status<>'WAIVED')),
  'maintenance',jsonb_build_object('due',(select count(*) from public.vehicle_maintenance_status where status='DUE_SOON'),'overdue',(select count(*) from public.vehicle_maintenance_status where status='OVERDUE'),'recorded_cost',(select coalesce(sum(cost),0) from public.maintenance_service_records where status='COMPLETED')),
  'customers',jsonb_build_object('active',(select count(*) from public.customers where status='ACTIVE'),'with_overdue',(select count(distinct a.customer_id) from public.agreements a join public.payment_schedule_items s on s.agreement_id=a.id where a.status='ACTIVE' and s.due_date<current_date and s.amount_paid<s.amount_due and s.status<>'WAIVED'),'rent_to_own',(select count(*) from public.agreements where status='ACTIVE' and agreement_type='RENT_TO_OWN')),
  'operations',jsonb_build_object('open_issues',(select count(*) from public.vehicle_issues where status not in('RESOLVED','CANCELLED')),'pickups_today',(select count(*) from public.pickup_checklists where scheduled_at::date=current_date and status not in('COMPLETED','CANCELLED')),'returns_today',(select count(*) from public.return_checklists where scheduled_at::date=current_date and status not in('COMPLETED','CANCELLED')))
 );
end $$;

revoke all on function public.daily_operations_snapshot(),public.management_report_snapshot() from public;
grant execute on function public.daily_operations_snapshot(),public.management_report_snapshot() to authenticated;

create or replace view public.payment_operations with(security_invoker=true) as
select s.id,s.agreement_id,a.customer_id,a.vehicle_id,c.full_name customer_name,v.registration,
 s.due_date,s.amount_due,s.amount_paid,(s.amount_due-s.amount_paid)::numeric(12,2) outstanding,
 case when s.status='WAIVED' then 'WAIVED' when s.amount_paid>=s.amount_due then 'PAID' when s.due_date<current_date then 'OVERDUE' when s.due_date=current_date then 'DUE' else 'UPCOMING' end effective_status,
 greatest(0,current_date-s.due_date) overdue_days,
 coalesce((select n.status from public.notifications n where n.agreement_id=a.id and n.type in('PAYMENT_DUE','PAYMENT_OVERDUE') order by n.created_at desc limit 1),'NOT_QUEUED') reminder_state
from public.payment_schedule_items s join public.agreements a on a.id=s.agreement_id
left join public.customers c on c.id=a.customer_id left join public.vehicles v on v.id=a.vehicle_id;
grant select on public.payment_operations to authenticated;

create table public.business_payment_setting_history(
 id bigint generated always as identity primary key,actor uuid not null references public.staff_profiles(user_id),changed_at timestamptz not null default now(),
 before_state jsonb not null,after_state jsonb not null,reason text not null check(btrim(reason)<>'' and length(reason)<=500)
);
create trigger business_payment_setting_history_immutable before update or delete on public.business_payment_setting_history for each row execute function app_private.immutable_operational_history();
alter table public.business_payment_setting_history enable row level security;
create policy admin_read_payment_setting_history on public.business_payment_setting_history for select to authenticated using(app_private.is_admin());
revoke all on public.business_payment_setting_history from anon,authenticated;grant select on public.business_payment_setting_history to authenticated;
create or replace function public.update_business_payment_instructions(p_instructions text,p_approved boolean,p_reason text) returns public.business_payment_settings
language plpgsql security definer set search_path='' as $$
declare old_row public.business_payment_settings;new_row public.business_payment_settings;
begin if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501';end if;if btrim(coalesce(p_reason,''))='' then raise exception 'change reason required';end if;if p_approved and btrim(coalesce(p_instructions,''))='' then raise exception 'approved instructions cannot be empty';end if;
 select * into old_row from public.business_payment_settings where id for update;
 update public.business_payment_settings set payid_instructions=nullif(btrim(p_instructions),''),customer_display_approved=p_approved,updated_by=auth.uid(),updated_at=now() where id returning * into new_row;
 insert into public.business_payment_setting_history(actor,before_state,after_state,reason)values(auth.uid(),to_jsonb(old_row)-'updated_by',to_jsonb(new_row)-'updated_by',btrim(p_reason));return new_row;end $$;
revoke all on function public.update_business_payment_instructions(text,boolean,text) from public;grant execute on function public.update_business_payment_instructions(text,boolean,text) to authenticated;

alter table public.scheduled_jobs drop constraint scheduled_jobs_job_key_check;
alter table public.scheduled_jobs add constraint scheduled_jobs_job_key_check check(job_key in('GENERATE_NOTIFICATIONS','PROCESS_LOCAL_NOTIFICATIONS','REFRESH_READINESS','REFRESH_OWNER','REFRESH_PORTAL_AGING','REFRESH_TOLL_FINE_ATTENTION','REFRESH_NOTIFICATION_ATTENTION','REFRESH_COLLECTIONS','EXPIRE_INVITATIONS'));
insert into public.scheduled_jobs(job_key,description,cadence_minutes) values('EXPIRE_INVITATIONS','Expire unused account invitations without staff interaction',60);

create or replace function app_private.execute_known_job(p_job_key text,p_actor uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb:=jsonb_build_object('actor',p_actor);claimed public.notifications;
begin
 case p_job_key
  when 'GENERATE_NOTIFICATIONS' then result:=jsonb_build_object('generated',public.generate_notifications(now()),'pre_due',public.generate_pre_due_payment_notifications(now()));
  when 'PROCESS_LOCAL_NOTIFICATIONS' then result:=jsonb_build_object('processed',0);for claimed in select * from public.claim_notifications(25,60) loop perform public.complete_notification(claimed.id,claimed.claim_token,'SUCCESS','local-'||claimed.id,null,null,0,'LOCAL_SYNTHETIC');result:=jsonb_set(result,'{processed}',to_jsonb((result->>'processed')::integer+1));end loop;
  when 'REFRESH_READINESS' then result:=jsonb_build_object('exceptions',public.refresh_readiness_exceptions(30,7),'maintenance',public.refresh_maintenance_compliance_attention());
  when 'REFRESH_OWNER' then perform public.refresh_owner_exceptions(14,2000);result:=jsonb_build_object('refreshed',true);
  when 'REFRESH_PORTAL_AGING' then result:=jsonb_build_object('exceptions',public.refresh_portal_exchange_exceptions());
  when 'REFRESH_TOLL_FINE_ATTENTION' then result:=jsonb_build_object('exceptions',public.refresh_toll_fine_owner_attention());
  when 'REFRESH_NOTIFICATION_ATTENTION' then result:=jsonb_build_object('exceptions',public.refresh_notification_attention());
  when 'REFRESH_COLLECTIONS' then perform public.run_collection_workflows(current_date);result:=jsonb_build_object('refreshed',true);
  when 'EXPIRE_INVITATIONS' then result:=jsonb_build_object('expired',public.expire_account_invitations());
  else raise exception 'unsupported scheduled job';
 end case;return result;
end $$;

comment on table public.rto_ownership_transfer_confirmations is 'Immutable staff confirmation that external/legal RTO ownership transfer occurred; Veera does not perform the transfer.';
