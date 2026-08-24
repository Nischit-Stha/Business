import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { assignException, extendOpenSchedules, resolveException } from '@/lib/exception-actions';
import { getOwnerDashboard } from '@/lib/owner';

const money = (value: number) => new Intl.NumberFormat('en-AU', { style: 'currency', currency: 'AUD' }).format(value ?? 0);
const label = (value: string) => value.replaceAll('_', ' ').toLowerCase().replace(/^./, (letter) => letter.toUpperCase());
const displayDate = (value: string) => new Date(/^\d{4}-\d{2}-\d{2}$/.test(value) ? `${value}T00:00:00` : value).toLocaleDateString('en-AU');

function Cards({ items }: { items: { label: string; value: string | number; alert?: boolean }[] }) {
  return <div className="summary-grid">{items.map((item) => <div className={item.alert ? 'summary-alert' : undefined} key={item.label}><small>{item.label}</small><strong>{item.value}</strong></div>)}</div>;
}

export default async function OwnerPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { dashboard, staff, profile } = await getOwnerDashboard();
  const { error } = await searchParams;
  const p = dashboard.payments; const f = dashboard.fleet; const m = dashboard.maintenance; const c = dashboard.customers;
  return <main><StaffNav/><div className="owner-heading"><div><p className="eyebrow">Management by exception</p><h1>Owner operations</h1><p className="lede">Today&apos;s business state and the work that needs attention.</p></div>{profile.role === 'ADMIN' && <form action={extendOpenSchedules}><button>Extend payment schedules</button></form>}</div>
    {error && <p className="error">{error}</p>}
    <section className="dashboard-section"><div className="section-heading"><h2>Owner attention queue</h2><span className="queue-count">{dashboard.attention.length} open</span></div>
      {dashboard.attention.length === 0 ? <p className="empty-state">Nothing currently requires owner attention.</p> : <div className="table-wrap attention-table"><table><thead><tr><th>Priority</th><th>Action required</th><th>Customer / vehicle</th><th>Due / created</th><th>View</th><th>Manage</th></tr></thead><tbody>{dashboard.attention.map((item) => <tr key={`${item.type}-${item.id}`}><td><span className={`status severity-${item.severity.toLowerCase()}`}>{item.severity}</span></td><td><strong>{label(item.type)}</strong><br/><span className="table-detail">{item.description}</span></td><td>{item.subject ?? '—'}</td><td>{displayDate(item.date)}</td><td><Link href={item.href}>Open</Link></td><td>{item.manageable ? <details><summary>Assign / resolve</summary><div className="queue-actions"><form action={assignException} className="compact-form"><input type="hidden" name="id" value={item.id}/><select aria-label="Assignee" name="assignedTo" defaultValue={profile.user_id}>{staff.map((person) => <option key={person.user_id} value={person.user_id}>{person.full_name}</option>)}</select><button>Assign</button></form><form action={resolveException} className="compact-form"><input type="hidden" name="id" value={item.id}/><input aria-label="Resolution note" name="resolutionNote" maxLength={500} required placeholder="Resolution note"/><button>Resolve</button></form></div></details> : 'Workflow'}</td></tr>)}</tbody></table></div>}
    </section>
    <section className="dashboard-section"><div className="section-heading"><h2>Payments</h2><Link href="/payments">View payments</Link></div><Cards items={[{label:'Expected today',value:money(p.expected_today)},{label:'Received today',value:money(p.received_today)},{label:'Overdue items',value:p.overdue_count,alert:p.overdue_count>0},{label:'Overdue amount',value:money(p.overdue_amount),alert:p.overdue_amount>0},{label:'Manual review',value:p.manual_review,alert:p.manual_review>0},{label:'Failed / ambiguous',value:p.failed_or_ambiguous,alert:p.failed_or_ambiguous>0}]}/></section>
    <div className="dashboard-columns"><section className="dashboard-section"><div className="section-heading"><h2>Fleet</h2><Link href="/fleet">View fleet</Link></div><Cards items={[{label:'Total vehicles',value:f.total},{label:'Rented',value:f.rented},{label:'Available',value:f.available},{label:'Pickup today',value:f.pickup_today,alert:f.pickup_today>0},{label:'Returning today',value:f.returning_today,alert:f.returning_today>0},{label:'Workshop / service',value:f.workshop,alert:f.workshop>0},{label:'Unavailable',value:f.unavailable,alert:f.unavailable>0}]}/></section>
    <section className="dashboard-section"><div className="section-heading"><h2>Maintenance</h2><Link href="/operations/maintenance">View service</Link></div><Cards items={[{label:'Within 1,000 km',value:m.approaching_service,alert:m.approaching_service>0},{label:'Service due',value:m.due_service,alert:m.due_service>0},{label:'Service overdue',value:m.overdue_service,alert:m.overdue_service>0},{label:'In workshop',value:m.in_workshop,alert:m.in_workshop>0}]}/></section></div>
    <section className="dashboard-section"><div className="section-heading"><h2>Customers</h2><Link href="/customers">View customers</Link></div><Cards items={[{label:'Pending Veera approval',value:c.pending_approval,alert:c.pending_approval>0},{label:'Active customers',value:c.active},{label:'With overdue payments',value:c.with_overdue_payments,alert:c.with_overdue_payments>0},{label:'Missing / expiring documents',value:c.missing_or_expiring_documents,alert:c.missing_or_expiring_documents>0}]}/></section>
  </main>;
}
