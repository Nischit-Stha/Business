import Link from 'next/link';
import { signOut } from '@/lib/auth-actions';

export function StaffNav() {
  return <nav><Link href="/owner">Owner</Link><Link href="/fleet">Fleet</Link><Link href="/operations/issues">Issues</Link><Link href="/customers">Customers</Link><Link href="/agreements">Agreements</Link><Link href="/payments">Payments</Link><Link href="/reconciliation">Reconciliation</Link><Link href="/collections">Collections</Link><Link href="/messaging">Messaging</Link><Link href="/tolls-fines">Tolls &amp; Fines</Link><Link href="/operations/customers">Readiness</Link><Link href="/operations/pickups">Pickups</Link><Link href="/operations/returns">Returns</Link><Link href="/operations/compliance">Compliance</Link><Link href="/operations/maintenance">Service</Link><Link href="/swap">Swap</Link><form action={signOut}><button className="link-button">Sign out</button></form></nav>;
}
