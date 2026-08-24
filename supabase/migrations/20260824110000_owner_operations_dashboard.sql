-- Read-only, staff-authorized aggregation for the owner operations dashboard.
-- Financial values are derived from the existing immutable payment and reconciliation ledgers.

create or replace function public.owner_operations_dashboard()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with latest_matches as (
    select distinct on (r.imported_bank_transaction_id)
      r.imported_bank_transaction_id, r.confidence
    from public.bank_match_runs r
    order by r.imported_bank_transaction_id, r.generated_at desc, r.id desc
  ), payment_metrics as (
    select jsonb_build_object(
      'expected_today', coalesce((select sum(p.amount_due) from public.payment_schedule_items p where p.due_date=current_date and p.status<>'WAIVED'),0),
      'received_today', coalesce((select sum(p.amount) from public.payment_transactions p where p.received_at>=current_date and p.received_at<current_date+1),0),
      'overdue_count', (select count(*) from public.payment_schedule_items p where p.due_date<current_date and p.status not in ('PAID','WAIVED')),
      'overdue_amount', coalesce((select sum(p.amount_due-p.amount_paid) from public.payment_schedule_items p where p.due_date<current_date and p.status not in ('PAID','WAIVED')),0),
      'manual_review', (select count(*) from public.imported_bank_transactions t where t.status='REVIEW_REQUIRED'),
      'failed_or_ambiguous', (select count(*) from public.imported_bank_transactions t left join latest_matches m on m.imported_bank_transaction_id=t.id where t.status='REVIEW_REQUIRED' and coalesce(m.confidence,'NO_MATCH') in ('NO_MATCH','AMBIGUOUS','LOW'))
    ) value
  ), fleet_metrics as (
    select jsonb_build_object(
      'total', count(*),
      'rented', count(*) filter(where operational_status='ASSIGNED'),
      'available', count(*) filter(where operational_status='AVAILABLE'),
      'pickup_today', (select count(*) from public.agreements a where a.start_date=current_date and a.status in ('PENDING_SIGNATURE','ACTIVE')),
      'returning_today', (select count(*) from public.agreements a where a.end_date=current_date and a.status in ('ACTIVE','SUSPENDED')),
      'workshop', count(*) filter(where operational_status='WORKSHOP'),
      'unavailable', count(*) filter(where operational_status in ('OFF_ROAD','PICKUP_PENDING','RETURN_PENDING'))
    ) value from public.vehicles
  ), maintenance_metrics as (
    select jsonb_build_object(
      'approaching_service', count(*) filter(where s.status='DUE_SOON'),
      'due_service', count(*) filter(where s.status='DUE_SOON'),
      'overdue_service', count(*) filter(where s.status='OVERDUE'),
      'in_workshop', (select count(*) from public.vehicles v where v.operational_status='WORKSHOP')
    ) value from public.vehicle_maintenance_status s
  ), overdue_customers as (
    select distinct a.customer_id
    from public.agreements a join public.payment_schedule_items p on p.agreement_id=a.id
    where a.customer_id is not null and p.due_date<current_date and p.status not in ('PAID','WAIVED')
  ), customer_metrics as (
    select jsonb_build_object(
      'pending_approval', (select count(*) from public.customer_approvals a where a.status='PENDING'),
      'active', (select count(*) from public.customers c where c.status='ACTIVE'),
      'with_overdue_payments', (select count(*) from overdue_customers),
      'missing_or_expiring_documents', (select count(distinct c.id) from public.customers c where c.status='ACTIVE' and (
        exists(select 1 from public.customer_documents d where d.customer_id=c.id and (d.status in ('MISSING','REJECTED','EXPIRED') or d.expiry_date<=current_date+30))
        or not exists(select 1 from public.customer_documents d where d.customer_id=c.id and d.document_type='DRIVER_LICENCE')
        or not exists(select 1 from public.customer_documents d where d.customer_id=c.id and d.document_type='PROOF_OF_ADDRESS')
      ))
    ) value
  ), attention_items as (
    select e.id,e.exception_type type,e.severity,e.summary description,coalesce(c.full_name,v.registration) subject,
      coalesce(e.metadata->>'expires_at',e.metadata->>'since',e.created_at::date::text) item_date,
      case
        when e.entity_type='customer' then '/customers/'||e.entity_id
        when e.entity_type='vehicle' and e.exception_type in ('SERVICE_DUE','SERVICE_OVERDUE') then '/operations/maintenance'
        when e.entity_type='vehicle' then '/fleet/'||e.entity_id
        when e.entity_type='imported_bank_transaction' then '/reconciliation/'||e.entity_id
        when e.entity_type='vehicle_issue' then '/operations/issues/'||e.entity_id
        when e.exception_type in ('OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','UNALLOCATED_FUNDS','PAYMENT_ALLOCATION') then '/payments'
        when e.entity_type='agreement' then '/agreements/'||e.entity_id
        when e.entity_type='pickup_checklist' then '/operations/pickups'
        when e.entity_type='return_checklist' then '/operations/returns'
        else '/owner' end href,
      e.status,true manageable,e.created_at sort_date
    from public.operational_exceptions e
    left join public.customers c on e.entity_type='customer' and c.id=e.entity_id
    left join public.vehicles v on e.entity_type='vehicle' and v.id=e.entity_id
    where e.status<>'RESOLVED' and (not e.owner_only or app_private.is_admin())
    union all
    select a.id,'PICKUP_TODAY','MEDIUM','Pickup scheduled today',concat_ws(' — ',c.full_name,v.registration),current_date::text,
      '/operations/pickups','OPEN',false,current_date::timestamptz
    from public.agreements a join public.customers c on c.id=a.customer_id join public.vehicles v on v.id=a.vehicle_id
    where a.start_date=current_date and a.status in ('PENDING_SIGNATURE','ACTIVE')
      and not exists(select 1 from public.pickup_checklists p where p.agreement_id=a.id and p.status='COMPLETED')
    union all
    select a.id,'RETURN_TODAY','MEDIUM','Vehicle return scheduled today',concat_ws(' — ',c.full_name,v.registration),current_date::text,
      '/operations/returns','OPEN',false,current_date::timestamptz
    from public.agreements a join public.customers c on c.id=a.customer_id join public.vehicles v on v.id=a.vehicle_id
    where a.end_date=current_date and a.status in ('ACTIVE','SUSPENDED')
      and not exists(select 1 from public.vehicle_assignments va where va.customer_id=a.customer_id and va.vehicle_id=a.vehicle_id and va.assignment_status='RETURNED' and va.returned_at::date=current_date)
  ), attention as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',i.id,'type',i.type,'severity',i.severity,'description',i.description,'subject',i.subject,
      'date',i.item_date,'href',i.href,'status',i.status,'manageable',i.manageable
    ) order by case i.severity when 'CRITICAL' then 0 when 'HIGH' then 1 when 'MEDIUM' then 2 else 3 end,i.sort_date,i.id),'[]'::jsonb) value
    from attention_items i
  )
  select jsonb_build_object('payments',p.value,'fleet',f.value,'maintenance',m.value,'customers',c.value,'attention',a.value)
  from payment_metrics p cross join fleet_metrics f cross join maintenance_metrics m cross join customer_metrics c cross join attention a
  where app_private.is_staff();
$$;

revoke all on function public.owner_operations_dashboard() from public;
grant execute on function public.owner_operations_dashboard() to authenticated;

comment on function public.owner_operations_dashboard() is
  'Staff-only operational summary. Excludes raw bank descriptions, references, payer fields, and customer contact details.';
