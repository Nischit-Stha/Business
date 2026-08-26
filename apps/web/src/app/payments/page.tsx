import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { getPaymentsDashboard } from '@/lib/agreements';
import { EmptyState, PageHeader, SectionCard, StatusBadge } from '@/components/ui';

type PaymentItems=Awaited<ReturnType<typeof getPaymentsDashboard>>['due'];
function PaymentTable({title,items,empty,today}:{title:string;items:PaymentItems;empty:string;today:number}){
 return <SectionCard title={title}>{items.length===0?<EmptyState title={empty}/>:<div className="payment-list">{items.map(x=>{
  const outstanding=Number(x.amount_due)-Number(x.amount_paid);const dueTime=new Date(`${x.due_date}T00:00:00`).getTime();const overdue=dueTime<today;const days=Math.max(0,Math.floor((today-dueTime)/86400000));
  return <article className="payment-row" key={x.id}><div><strong>{x.customer_name??'Customer'}</strong><span>{x.registration??'Agreement'}</span></div><dl><div><dt>Weekly rent</dt><dd>${Number(x.amount_due).toFixed(2)}</dd></div><div><dt>Due</dt><dd>{new Date(`${x.due_date}T00:00:00`).toLocaleDateString('en-AU',{day:'numeric',month:'short'})}</dd></div><div><dt>Status</dt><dd><StatusBadge status={overdue&&outstanding>0?'OVERDUE':outstanding<=0?'PAID':'DUE'}/>{overdue&&outstanding>0&&<small>{days} day{days===1?'':'s'} overdue</small>}</dd></div><div><dt>Outstanding</dt><dd><strong>${outstanding.toFixed(2)}</strong></dd></div><div><dt>Reminder</dt><dd>{x.reminder_state?.replaceAll('_',' ')??'Not queued'}</dd></div></dl><Link className="action-button button-secondary" href={`/agreements/${x.agreement_id}`}>View</Link></article>})}</div>}</SectionCard>
}
// Server-render time is captured once so every row uses a consistent overdue boundary.
// eslint-disable-next-line react-hooks/purity
export default async function PaymentsPage(){const groups=await getPaymentsDashboard();const today=Date.now();return <main id="main-content"><StaffNav/><PageHeader eyebrow="Finance" title="Payments" description="What’s due, overdue, paid and ready for staff review." actions={<Link className="action-button button-secondary" href="/reconciliation">Advanced reconciliation</Link>}/><div className="filter-bar"><a className="active" href="#due">Due today</a><a href="#overdue">Overdue</a><a href="#paid">Paid</a><Link href="/reconciliation">Needs review</Link></div><div id="due"><PaymentTable title="Due today" empty="Nothing else is due today." items={groups.due} today={today}/></div><div id="overdue"><PaymentTable title="Overdue" empty="Everyone is up to date." items={groups.overdue} today={today}/></div><PaymentTable title="Upcoming" empty="No upcoming payments." items={groups.upcoming} today={today}/><div id="paid"><PaymentTable title="Paid" empty="No payment history yet." items={groups.paid} today={today}/></div></main>}
