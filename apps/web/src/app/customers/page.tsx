import Link from 'next/link';
import { getCustomers } from '@/lib/fleet';

export const dynamic = 'force-dynamic';

export default async function CustomersPage() {
  const customers = await getCustomers();
  return <main><nav><Link href="/">Home</Link><Link href="/fleet">Fleet</Link><Link href="/assignments">Assignments</Link></nav><p className="eyebrow">Operations</p><h1>Customers</h1><div className="table-wrap"><table><thead><tr><th>Name</th><th>Phone</th><th>Email</th><th>Licence expiry</th><th>Status</th></tr></thead><tbody>{customers.map((customer) => <tr key={customer.id}><td><strong>{customer.full_name}</strong></td><td>{customer.phone ?? '—'}</td><td>{customer.email ?? '—'}</td><td>{customer.licence_expiry ?? '—'}</td><td>{customer.status}</td></tr>)}</tbody></table></div>{customers.length === 0 && <p className="empty">No customer data is available to this session.</p>}</main>;
}
