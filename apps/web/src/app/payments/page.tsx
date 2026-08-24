import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { getPaymentsDashboard } from '@/lib/agreements';

function PaymentTable({ title, items }: { title: string; items: Awaited<ReturnType<typeof getPaymentsDashboard>>['due'] }) {
  return <><h2>{title}</h2><div className="table-wrap"><table><thead><tr><th>Due date</th><th>Customer</th><th>Vehicle</th><th>Due</th><th>Paid</th></tr></thead><tbody>{items.map((x) => <tr key={x.id}><td><Link href={`/agreements/${x.agreement_id}`}>{x.due_date}</Link></td><td>{x.agreements[0]?.customers[0]?.full_name}</td><td>{x.agreements[0]?.vehicles[0]?.registration}</td><td>${Number(x.amount_due).toFixed(2)}</td><td>${Number(x.amount_paid).toFixed(2)}</td></tr>)}</tbody></table></div>{items.length === 0 && <p className="empty">None.</p>}</>;
}
export default async function PaymentsPage() { const groups = await getPaymentsDashboard(); return <main><StaffNav/><p className="eyebrow">Operations</p><h1>Payments</h1><p className="lede">Manual PayID tracking only. Status is derived against today when displayed.</p><PaymentTable title="Due today" items={groups.due}/><PaymentTable title="Overdue" items={groups.overdue}/><PaymentTable title="Upcoming" items={groups.upcoming}/><PaymentTable title="Paid history" items={groups.paid}/></main>; }
