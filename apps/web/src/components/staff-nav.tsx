import Link from 'next/link';
import { signOut } from '@/lib/auth-actions';

export function StaffNav() {
  return <nav><Link href="/owner">Owner</Link><Link href="/fleet">Fleet</Link><Link href="/customers">Customers</Link><Link href="/assignments">Assignments</Link><Link href="/agreements">Agreements</Link><Link href="/payments">Payments</Link><Link href="/assign">Assign</Link><Link href="/return">Return</Link><Link href="/swap">Swap</Link><form action={signOut}><button className="link-button">Sign out</button></form></nav>;
}
