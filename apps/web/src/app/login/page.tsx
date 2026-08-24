import { redirect } from 'next/navigation';
import { signIn } from '@/lib/auth-actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (user) redirect('/fleet');
  const { error } = await searchParams;
  return <main className="auth-shell"><p className="eyebrow">Veera Rentals</p><h1>Staff sign in</h1><p>Use the account provisioned by an administrator. Public registration is not available.</p>{error && <p className="error" role="alert">{error}</p>}<form action={signIn} className="form-card"><label>Email<input name="email" type="email" autoComplete="email" required /></label><label>Password<input name="password" type="password" autoComplete="current-password" required /></label><button type="submit">Sign in</button></form></main>;
}
