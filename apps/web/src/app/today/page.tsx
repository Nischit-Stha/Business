import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { PageHeader, SeverityBadge, StatusBadge } from '@/components/ui';
import { requireStaff } from '@/lib/auth';
const when = (value: string) => new Date(value).toLocaleString('en-AU');
export default async function Today() {
  const { supabase } = await requireStaff();
  const [
    payments,
    pickups,
    returns,
    issues,
    maintenance,
    compliance,
    approvals,
    requests,
    notifications,
  ] = await Promise.all([
    supabase
      .from('payment_operations')
      .select(
        'id,agreement_id,customer_name,registration,due_date,outstanding,overdue_days',
      )
      .eq('effective_status', 'OVERDUE')
      .order('overdue_days', { ascending: false })
      .limit(6),
    supabase
      .from('pickup_checklists')
      .select(
        'id,scheduled_at,status,customers(full_name),vehicles(registration)',
      )
      .not('status', 'in', '(COMPLETED,CANCELLED)')
      .order('scheduled_at')
      .limit(6),
    supabase
      .from('return_checklists')
      .select(
        'id,scheduled_at,status,vehicle_assignments(customers(full_name),vehicles(registration))',
      )
      .not('status', 'in', '(COMPLETED,CANCELLED)')
      .order('scheduled_at')
      .limit(6),
    supabase
      .from('vehicle_issues')
      .select(
        'id,severity,category,description,created_at,vehicles(registration),customers(full_name)',
      )
      .in('severity', ['HIGH', 'CRITICAL'])
      .not('status', 'in', '(RESOLVED,CANCELLED)')
      .order('severity')
      .limit(6),
    supabase
      .from('vehicle_maintenance_status')
      .select('vehicle_id,status,km_remaining,vehicles(registration)')
      .in('status', ['DUE_SOON', 'OVERDUE', 'IN_PROGRESS'])
      .order('km_remaining')
      .limit(6),
    supabase
      .from('vehicle_compliance_exposure')
      .select(
        'vehicle_id,compliance_type,exposure,expires_at,vehicles(registration)',
      )
      .neq('exposure', 'VALID')
      .order('expires_at')
      .limit(6),
    supabase
      .from('customer_approvals')
      .select('customer_id,status,customers(full_name)')
      .eq('status', 'PENDING')
      .limit(6),
    supabase
      .from('customer_portal_requests')
      .select('id,request_type,status,created_at,customers(full_name)')
      .in('status', ['OPEN', 'SUBMITTED', 'IN_REVIEW'])
      .order('created_at')
      .limit(6),
    supabase
      .from('notification_attention')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(6),
  ]);
  const sections = [
    {
      title: 'Overdue payments',
      urgent: (payments.data?.length ?? 0) > 0,
      href: '/payments#overdue',
      rows: payments.data?.map((x) => ({
        id: x.id,
        title: `${x.customer_name} · ${x.registration}`,
        detail: `$${Number(x.outstanding).toFixed(2)} outstanding · ${x.overdue_days} days overdue`,
        action: 'Review payment',
        href: `/agreements/${x.agreement_id}`,
      })),
    },
    {
      title: 'Pickup handovers',
      urgent: false,
      href: '/operations/pickups',
      rows: pickups.data?.map((x) => ({
        id: x.id,
        title: `${x.vehicles?.[0]?.registration} · ${x.customers?.[0]?.full_name}`,
        detail: `${when(x.scheduled_at)} · ${x.status.toLowerCase()}`,
        action: 'Open checklist',
        href: '/operations/pickups',
      })),
    },
    {
      title: 'Vehicle returns',
      urgent: false,
      href: '/operations/returns',
      rows: returns.data?.map((x) => ({
        id: x.id,
        title: `${x.vehicle_assignments?.[0]?.vehicles?.[0]?.registration} · ${x.vehicle_assignments?.[0]?.customers?.[0]?.full_name}`,
        detail: `${when(x.scheduled_at)} · ${x.status.toLowerCase()}`,
        action: 'Open return',
        href: '/operations/returns',
      })),
    },
    {
      title: 'High-priority vehicle issues',
      urgent: (issues.data?.length ?? 0) > 0,
      href: '/operations/issues',
      rows: issues.data?.map((x) => ({
        id: x.id,
        title: `${x.vehicles?.[0]?.registration} · ${x.category.replaceAll('_', ' ').toLowerCase()}`,
        detail: `${x.customers?.[0]?.full_name ?? 'No customer'} · ${x.description}`,
        action: 'Handle issue',
        href: `/operations/issues/${x.id}`,
        severity: x.severity,
      })),
    },
    {
      title: 'Service and compliance blockers',
      urgent:
        (maintenance.data?.some((x) => x.status === 'OVERDUE') ||
          compliance.data?.some((x) =>
            ['EXPIRED', 'MISSING'].includes(x.exposure),
          )) ??
        false,
      href: '/operations/compliance',
      rows: [
        ...(maintenance.data?.map((x) => ({
          id: `m-${x.vehicle_id}`,
          title: `${x.vehicles?.[0]?.registration} · Service`,
          detail: x.status.replaceAll('_', ' ').toLowerCase(),
          action: 'Review service',
          href: '/operations/maintenance',
        })) ?? []),
        ...(compliance.data?.map((x) => ({
          id: `c-${x.vehicle_id}-${x.compliance_type}`,
          title: `${x.vehicles?.[0]?.registration} · ${x.compliance_type}`,
          detail: `${x.exposure.replaceAll('_', ' ').toLowerCase()}${x.expires_at ? ` · ${x.expires_at}` : ''}`,
          action: 'Review compliance',
          href: '/operations/compliance',
        })) ?? []),
      ].slice(0, 6),
    },
    {
      title: 'Pending customer approvals',
      urgent: false,
      href: '/operations/customers',
      rows: approvals.data?.map((x) => ({
        id: x.customer_id,
        title: x.customers?.[0]?.full_name ?? 'Customer',
        detail: 'Approval decision is pending',
        action: 'Review readiness',
        href: '/operations/customers',
      })),
    },
    {
      title: 'Customer portal requests',
      urgent: false,
      href: '/operations/portal-requests',
      rows: requests.data?.map((x) => ({
        id: x.id,
        title: `${x.customers?.[0]?.full_name} · ${x.request_type.replaceAll('_', ' ').toLowerCase()}`,
        detail: `Received ${when(x.created_at)} · ${x.status.toLowerCase()}`,
        action: 'Respond',
        href: '/operations/portal-requests',
      })),
    },
    {
      title: 'Notification failures',
      urgent: (notifications.data?.length ?? 0) > 0,
      href: '/notifications',
      rows: notifications.data?.map((x) => ({
        id: x.id,
        title: `${x.customer_name ?? 'Customer'} · ${x.type.replaceAll('_', ' ').toLowerCase()}`,
        detail: x.attention_reason.replaceAll('_', ' ').toLowerCase(),
        action: 'Review delivery',
        href: '/notifications',
      })),
    },
  ];
  return (
    <main id="main-content">
      <StaffNav />
      <PageHeader
        eyebrow="Daily operations"
        title="Today"
        description="Highest-impact work first. Open an item to see the full record and take action."
      />
      <div className="today-sections">
        {sections
          .filter((s) => (s.rows?.length ?? 0) > 0)
          .map((section) => (
            <section className="section-card" key={section.title}>
              <div className="section-card-header">
                <div>
                  <h2>{section.title}</h2>
                  <p>
                    {section.rows?.length} item
                    {section.rows?.length === 1 ? '' : 's'} shown
                  </p>
                </div>
                {section.urgent ? (
                  <SeverityBadge severity="HIGH" />
                ) : (
                  <StatusBadge status="ACTION_NEEDED" />
                )}
              </div>
              <div className="attention-list">
              {(section.rows as Array<{id:string;title:string;detail:string;action:string;href:string;severity?:string}>|undefined)?.map((row) => (
                <article className="attention-item" key={row.id}>
                  {row.severity && (
                      <SeverityBadge severity={row.severity} />
                    )}
                    <div className="attention-copy">
                      <strong>{row.title}</strong>
                      <p>{row.detail}</p>
                    </div>
                    <Link
                      className="action-button button-secondary"
                      href={row.href}
                    >
                      {row.action}
                    </Link>
                  </article>
                ))}
              </div>
              <Link href={section.href}>
                View all {section.title.toLowerCase()} →
              </Link>
            </section>
          ))}
        {sections.every((s) => (s.rows?.length ?? 0) === 0) && (
          <section className="empty-state">
            <h2>No urgent work is waiting</h2>
            <p>Today’s operational queues are clear.</p>
          </section>
        )}
      </div>
    </main>
  );
}
