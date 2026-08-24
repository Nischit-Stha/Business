import { StaffNav } from '@/components/staff-nav';
import { assignException, extendOpenSchedules, resolveException } from '@/lib/exception-actions';
import { getOwnerDashboard } from '@/lib/owner';

function money(value: unknown) { return `$${Number(value ?? 0).toFixed(2)}`; }

export default async function OwnerPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { metrics, exceptions, staff, profile } = await getOwnerDashboard();
  const { error } = await searchParams;
  return <main><StaffNav/><p className="eyebrow">Management by exception</p><h1>Owner dashboard</h1>
    {error && <p className="error">{error}</p>}
    <div className="summary-grid"><div><small>Active vehicles</small><strong>{metrics?.active_vehicles ?? 0}</strong></div><div><small>Available vehicles</small><strong>{metrics?.available_vehicles ?? 0}</strong></div><div><small>Active agreements</small><strong>{metrics?.active_agreements ?? 0}</strong></div><div><small>Overdue amount</small><strong>{money(metrics?.overdue_amount)}</strong></div><div><small>Overdue customers</small><strong>{metrics?.overdue_customers ?? 0}</strong></div><div><small>Needs attention</small><strong>{metrics?.attention_items ?? 0}</strong></div></div>
    {profile.role === 'ADMIN' && <form action={extendOpenSchedules}><button>Run safe schedule extension</button></form>}
    <h2>Attention queue</h2>
    {exceptions.length === 0 ? <p className="empty">Nothing currently needs attention.</p> : <div className="table-wrap"><table><thead><tr><th>Severity</th><th>Issue</th><th>Age</th><th>Status</th><th>Assign</th><th>Resolve</th></tr></thead><tbody>{exceptions.map((item) => <tr key={item.id}><td><span className={`status severity-${item.severity.toLowerCase()}`}>{item.severity}</span></td><td><strong>{item.exception_type.replaceAll('_',' ')}</strong><br/>{item.summary}</td><td>{new Date(item.created_at).toLocaleDateString('en-AU')}</td><td>{item.status}</td><td><form action={assignException} className="compact-form"><input type="hidden" name="id" value={item.id}/><select name="assignedTo" defaultValue={item.assigned_to ?? profile.user_id}>{staff.map((person) => <option key={person.user_id} value={person.user_id}>{person.full_name}</option>)}</select><button>Assign</button></form></td><td><form action={resolveException} className="compact-form"><input type="hidden" name="id" value={item.id}/><input name="resolutionNote" maxLength={500} required placeholder="Resolution note"/><button>Resolve</button></form></td></tr>)}</tbody></table></div>}
  </main>;
}
