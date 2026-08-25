import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { assignException, extendOpenSchedules, resolveException } from '@/lib/exception-actions';
import { getOwnerDashboard } from '@/lib/owner';
import { EmptyState, MetricCard, PageHeader, SeverityBadge } from '@/components/ui';

const money = (value: number) => new Intl.NumberFormat('en-AU', { style: 'currency', currency: 'AUD' }).format(value ?? 0);
const label = (value: string) => value.replaceAll('_', ' ').toLowerCase().replace(/^./, (letter) => letter.toUpperCase());
const displayDate = (value: string) => new Date(/^\d{4}-\d{2}-\d{2}$/.test(value) ? `${value}T00:00:00` : value).toLocaleDateString('en-AU');

function Cards({ items }: { items: { label: string; value: string | number; alert?: boolean }[] }) {
  return <div className="summary-grid">{items.map((item) => <MetricCard tone={item.alert?'warning':'default'} key={item.label} label={item.label} value={item.value}/>)}</div>;
}

export default async function OwnerPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { dashboard, staff, profile } = await getOwnerDashboard();
  const { error } = await searchParams;
  const p = dashboard.payments; const f = dashboard.fleet; const m = dashboard.maintenance; const c = dashboard.customers;
  const hour=new Date().getHours();const greeting=hour<12?'Good morning':hour<18?'Good afternoon':'Good evening';
  return <main id="main-content"><StaffNav/><PageHeader eyebrow="Veera operations · Today" title={`${greeting}, ${profile.full_name.split(' ')[0]}`} description="Here’s what needs attention across the business." actions={profile.role === 'ADMIN'&&<form action={extendOpenSchedules}><button>Extend payment schedules</button></form>}/>
    {error && <p className="error">{error}</p>}
    <section className="dashboard-section attention-panel" id="attention"><div className="attention-summary"><div><span className="attention-pulse" aria-hidden="true">!</span><div><p>Attention queue</p><h2>{dashboard.attention.length} {dashboard.attention.length===1?'item needs':'items need'} your attention</h2></div></div><span className="queue-count">Highest priority first</span></div><div className="filter-bar"><a href="#attention" className="active">All</a><Link href="/payments">Payments</Link><Link href="/fleet">Fleet</Link><Link href="/customers">Customers</Link><Link href="/operations/maintenance">Maintenance</Link></div>
      {dashboard.attention.length === 0 ? <EmptyState title="Everything is under control" description="Nothing currently requires owner attention."/> : <div className="attention-list">{dashboard.attention.map((item) => <article className={`attention-item priority-${item.severity.toLowerCase()}`} key={`${item.type}-${item.id}`}><SeverityBadge severity={item.severity}/><div className="attention-copy"><strong>{label(item.type)}</strong><p>{item.description}</p><small>{item.subject ?? 'Business operations'} · {displayDate(item.date)}</small></div><Link className="action-button button-secondary" href={item.href}>Open</Link>{item.manageable&&<details><summary>Manage</summary><div className="queue-actions"><form action={assignException} className="compact-form"><input type="hidden" name="id" value={item.id}/><select aria-label="Assignee" name="assignedTo" defaultValue={profile.user_id}>{staff.map(person=><option key={person.user_id} value={person.user_id}>{person.full_name}</option>)}</select><button>Assign</button></form><form action={resolveException} className="compact-form"><input type="hidden" name="id" value={item.id}/><input aria-label="Resolution note" name="resolutionNote" maxLength={500} required placeholder="Resolution note"/><button>Resolve</button></form></div></details>}</article>)}</div>}
    </section>
    <section className="dashboard-section"><div className="section-heading"><h2>Payments</h2><Link href="/payments">View payments</Link></div><Cards items={[{label:'Expected today',value:money(p.expected_today)},{label:'Received today',value:money(p.received_today)},{label:'Overdue items',value:p.overdue_count,alert:p.overdue_count>0},{label:'Overdue amount',value:money(p.overdue_amount),alert:p.overdue_amount>0},{label:'Manual review',value:p.manual_review,alert:p.manual_review>0},{label:'Failed / ambiguous',value:p.failed_or_ambiguous,alert:p.failed_or_ambiguous>0}]}/></section>
    <div className="dashboard-columns"><section className="dashboard-section"><div className="section-heading"><h2>Fleet</h2><Link href="/fleet">View fleet</Link></div><Cards items={[{label:'Total vehicles',value:f.total},{label:'Rented',value:f.rented},{label:'Available',value:f.available},{label:'Pickup today',value:f.pickup_today,alert:f.pickup_today>0},{label:'Returning today',value:f.returning_today,alert:f.returning_today>0},{label:'Workshop / service',value:f.workshop,alert:f.workshop>0},{label:'Unavailable',value:f.unavailable,alert:f.unavailable>0}]}/></section>
    <section className="dashboard-section"><div className="section-heading"><h2>Maintenance</h2><Link href="/operations/maintenance">View service</Link></div><Cards items={[{label:'Within 1,000 km',value:m.approaching_service,alert:m.approaching_service>0},{label:'Service due',value:m.due_service,alert:m.due_service>0},{label:'Service overdue',value:m.overdue_service,alert:m.overdue_service>0},{label:'In workshop',value:m.in_workshop,alert:m.in_workshop>0}]}/></section></div>
    <section className="dashboard-section"><div className="section-heading"><h2>Customers</h2><Link href="/customers">View customers</Link></div><Cards items={[{label:'Pending Veera approval',value:c.pending_approval,alert:c.pending_approval>0},{label:'Active customers',value:c.active},{label:'With overdue payments',value:c.with_overdue_payments,alert:c.with_overdue_payments>0},{label:'Missing / expiring documents',value:c.missing_or_expiring_documents,alert:c.missing_or_expiring_documents>0}]}/></section>
  </main>;
}
