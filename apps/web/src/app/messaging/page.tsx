import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';
export default async function MessagingPage() {
  const { supabase } = await requireStaff();
  const { data } = await supabase
    .from('message_deliveries')
    .select('id,template_key,channel,status,created_at,customers(full_name)')
    .order('created_at', { ascending: false })
    .limit(100);
  return (
    <main>
      <StaffNav />
      <p className="eyebrow">Legacy delivery history</p>
      <h1>Messaging has moved</h1>
      <div className="callout">
        <strong>
          Use Notification operations for all current customer reminders and
          delivery failures.
        </strong>
        <p>
          This read-only history remains available during migration. Do not
          generate, retry, or cancel messages here.
        </p>
        <Link className="primary-link" href="/notifications">
          Open Notification operations
        </Link>
      </div>
      <section>
        <h2>Legacy message history</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Created</th>
                <th>Customer</th>
                <th>Template</th>
                <th>Channel</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {data?.map((d) => (
                <tr key={d.id}>
                  <td>{new Date(d.created_at).toLocaleString('en-AU')}</td>
                  <td>{d.customers?.[0]?.full_name ?? '—'}</td>
                  <td>{d.template_key.replaceAll('_', ' ').toLowerCase()}</td>
                  <td>{d.channel}</td>
                  <td>{d.status.replaceAll('_', ' ').toLowerCase()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
