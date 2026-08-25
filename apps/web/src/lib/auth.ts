import 'server-only';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function requireStaff() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('staff_profiles')
    .select('user_id, full_name, role, status')
    .eq('user_id', user.id)
    .eq('status', 'ACTIVE')
    .eq('is_active', true)
    .maybeSingle();
  if (!profile) redirect('/access-denied');
  return { supabase, user, profile };
}

export async function requireAdmin() {
  const context = await requireStaff();
  if (context.profile.role !== 'ADMIN') redirect('/access-denied');
  return context;
}

/** Sensitive actions require AAL2 when enrolled, otherwise a session issued in the last 10 minutes. */
export async function requireFreshAdmin() {
  const context = await requireAdmin();
  const [{ data: assurance }, { data: sessionData }] = await Promise.all([
    context.supabase.auth.mfa.getAuthenticatorAssuranceLevel(), context.supabase.auth.getSession(),
  ]);
  const issuedAt = sessionData.session?.user.last_sign_in_at ? Date.parse(sessionData.session.user.last_sign_in_at) : 0;
  if (assurance?.currentLevel !== 'aal2' && Date.now() - issuedAt > 10 * 60 * 1000) redirect('/login?error=Please%20sign%20in%20again%20for%20this%20sensitive%20action');
  return context;
}

export async function requireCustomer() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/portal/login');
  const { data: account } = await supabase.from('customer_portal_accounts').select('customer_id,status').eq('user_id',user.id).eq('status','ACTIVE').maybeSingle();
  if (!account) redirect('/portal/access-denied');
  return { supabase, user, customerId: account.customer_id };
}
