import 'server-only';
import { createClient } from '@supabase/supabase-js';
import { readPrivateEnvironment } from '@/lib/env';

export function createSupabaseAdminClient() {
  const { supabaseUrl, supabaseServiceRoleKey } = readPrivateEnvironment();
  return createClient(supabaseUrl, supabaseServiceRoleKey, { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } });
}
