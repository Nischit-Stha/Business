import { portalSignOut } from '@/lib/portal-actions';
export default function PortalDenied(){return <main className="auth-shell portal-shell"><h1>Portal access unavailable</h1><p>This account does not have active customer portal access. Contact Veera Rentals for help.</p><form action={portalSignOut}><button>Sign out</button></form></main>}
