import 'server-only';

import { requireStaff } from '@/lib/auth';

export async function getOwnerDashboard() {
  const { supabase, profile } = await requireStaff();
  await supabase.rpc('refresh_owner_exceptions', { p_overdue_days: 14, p_large_balance: 2000 });
  const [metrics, exceptions, staff] = await Promise.all([
    supabase.rpc('owner_dashboard_metrics', { p_overdue_days: 14 }),
    supabase.from('operational_exceptions').select('*').neq('status', 'RESOLVED').order('created_at'),
    supabase.from('staff_profiles').select('user_id, full_name').eq('status', 'ACTIVE').eq('is_active', true).order('full_name'),
  ]);
  const error = metrics.error ?? exceptions.error ?? staff.error;
  if (error) throw new Error(`Unable to load owner dashboard: ${error.message}`);
  const severityOrder: Record<string, number> = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };
  const queue = [...(exceptions.data ?? [])].sort((a, b) =>
    (severityOrder[a.severity] ?? 9) - (severityOrder[b.severity] ?? 9) || a.created_at.localeCompare(b.created_at));
  return { metrics: metrics.data?.[0], exceptions: queue, staff: staff.data ?? [], profile };
}
