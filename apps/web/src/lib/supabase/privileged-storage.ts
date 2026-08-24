import 'server-only';

import { createClient } from '@supabase/supabase-js';
import { readPrivateEnvironment } from '@/lib/env';

/** Server-only client. Keep its use restricted to private document object operations. */
export function createPrivilegedStorageClient() {
  const { supabaseUrl, supabaseServiceRoleKey } = readPrivateEnvironment();
  return createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
