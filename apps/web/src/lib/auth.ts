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
