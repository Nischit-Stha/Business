import Link from 'next/link';
import { getCustomers } from '@/lib/fleet';
import { StaffNav } from '@/components/staff-nav';

export const dynamic = 'force-dynamic';

export default async function CustomersPage() {
  const customers = await getCustomers();
  return <main><StaffNav/><p className="eyebrow">Operations</p><h1>Customers</h1><Link className="primary-link" href="/customers/new">Create customer</Link><div className="table-wrap"><table><thead><tr><th>Name</th><th>Phone</th><th>Email</th><th>Licence expiry</th><th>Status</th></tr></thead><tbody>{customers.map((customer) => <tr key={customer.id}><td><Link href={`/customers/${customer.id}`}><strong>{customer.full_name}</strong></Link></td><td>{customer.phone ?? '—'}</td><td>{customer.email ?? '—'}</td><td>{customer.licence_expiry ?? '—'}</td><td>{customer.status}</td></tr>)}</tbody></table></div>{customers.length === 0 && <p className="empty">No customers yet.</p>}</main>;
}
