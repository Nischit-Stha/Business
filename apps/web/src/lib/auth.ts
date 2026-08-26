import 'server-only';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { adminMfaDecision } from '@/lib/mfa-policy';

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
  const { data: assurance } = await context.supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  const decision = adminMfaDecision({ role: context.profile.role, currentLevel: assurance?.currentLevel ?? null, nextLevel: assurance?.nextLevel ?? null, enforcement: process.env.ADMIN_MFA_ENFORCEMENT });
  if (decision === 'challenge') redirect('/admin/mfa?mode=challenge');
  if (decision === 'enroll') redirect('/admin/mfa?mode=enroll');
  return context;
}

/** Sensitive actions always require AAL2 outside the explicitly documented rollout window. */
export async function requireFreshAdmin() {
  const context = await requireStaff();
  if (context.profile.role !== 'ADMIN') redirect('/access-denied');
  const [{ data: assurance }, { data: sessionData }] = await Promise.all([
    context.supabase.auth.mfa.getAuthenticatorAssuranceLevel(), context.supabase.auth.getSession(),
  ]);
  const issuedAt = sessionData.session?.user.last_sign_in_at ? Date.parse(sessionData.session.user.last_sign_in_at) : 0;
  if (assurance?.currentLevel !== 'aal2') {
    if (assurance?.nextLevel === 'aal2') redirect('/admin/mfa?mode=challenge');
    if (process.env.ADMIN_MFA_ENFORCEMENT === 'required' || Date.now() - issuedAt > 10 * 60 * 1000) redirect('/admin/mfa?mode=enroll');
  }
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
