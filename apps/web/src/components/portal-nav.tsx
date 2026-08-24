import Link from 'next/link';
import { portalSignOut } from '@/lib/portal-actions';
export function PortalNav(){return <nav className="portal-nav" aria-label="Customer portal"><Link href="/portal">Home</Link><Link href="/portal/payments">Payments</Link><Link href="/portal/my-car">My Car</Link><Link href="/portal/issues">Issues</Link><Link href="/portal/documents">Documents</Link><Link href="/portal/profile">Profile</Link><form action={portalSignOut}><button className="link-button">Sign out</button></form></nav>}
