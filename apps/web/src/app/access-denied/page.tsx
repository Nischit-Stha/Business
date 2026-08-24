import { signOut } from '@/lib/auth-actions';
export default function AccessDeniedPage() { return <main><p className="eyebrow">Access denied</p><h1>No active staff access</h1><p>Your account is authenticated but does not have an active staff profile. Contact an administrator.</p><form action={signOut}><button>Sign out</button></form></main>; }
