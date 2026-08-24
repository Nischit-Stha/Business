import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { getAgreements } from '@/lib/agreements';

export const dynamic = 'force-dynamic';
const filters = { active: ['ACTIVE','SUSPENDED'], pending: ['DRAFT','PENDING_SIGNATURE'], completed: ['COMPLETED','CANCELLED'] } as const;

export default async function AgreementsPage({ searchParams }: { searchParams: Promise<{ view?: string }> }) {
  const requested = (await searchParams).view ?? 'active';
  const view = requested in filters ? requested as keyof typeof filters : 'active';
  const agreements = await getAgreements([...filters[view]]);
  return <main><StaffNav/><p className="eyebrow">Operations</p><h1>Agreements</h1>
    <Link className="primary-link" href="/agreements/new">Create agreement</Link>
    <div className="tabs"><Link href="/agreements?view=active">Active</Link><Link href="/agreements?view=pending">Pending</Link><Link href="/agreements?view=completed">Completed</Link></div>
    <div className="table-wrap"><table><thead><tr><th>Customer</th><th>Vehicle</th><th>Type</th><th>Weekly</th><th>Status</th><th>Period</th></tr></thead>
    <tbody>{agreements.map((a) => <tr key={a.id}><td><Link href={`/agreements/${a.id}`}>{a.customers[0]?.full_name ?? 'Unassigned'}</Link></td><td>{a.vehicles[0]?.registration ?? 'Unassigned'}</td><td>{a.agreement_type.replaceAll('_',' ')}</td><td>${Number(a.weekly_amount).toFixed(2)}</td><td><span className="status">{a.status}</span></td><td>{a.start_date} — {a.end_date ?? 'Open'}</td></tr>)}</tbody></table></div>
    {agreements.length === 0 && <p className="empty">No {view} agreements.</p>}</main>;
}
