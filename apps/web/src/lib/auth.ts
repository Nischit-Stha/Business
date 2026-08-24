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

export async function requireCustomer() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/portal/login');
  const { data: account } = await supabase.from('customer_portal_accounts').select('customer_id,status').eq('user_id',user.id).eq('status','ACTIVE').maybeSingle();
  if (!account) redirect('/portal/access-denied');
  return { supabase, user, customerId: account.customer_id };
}
