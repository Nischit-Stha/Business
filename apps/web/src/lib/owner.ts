import 'server-only';

import { requireStaff } from '@/lib/auth';
import { prioritizeAttention, type OwnerDashboard } from '@/lib/owner-dashboard';

export async function getOwnerDashboard() {
  const { supabase, profile } = await requireStaff();
  await supabase.rpc('refresh_owner_exceptions', { p_overdue_days: 14, p_large_balance: 2000 });
  await supabase.rpc('refresh_readiness_exceptions', { p_expiring_days: 30, p_offroad_days: 7 });
  await supabase.rpc('refresh_maintenance_compliance_attention');
  await supabase.rpc('refresh_portal_exchange_exceptions');
  const [dashboard, staff] = await Promise.all([
    supabase.rpc('owner_operations_dashboard'),
    supabase.from('staff_profiles').select('user_id, full_name').eq('status', 'ACTIVE').eq('is_active', true).order('full_name'),
  ]);
  const error = dashboard.error ?? staff.error;
  if (error) throw new Error(`Unable to load owner dashboard: ${error.message}`);
  const data = dashboard.data as OwnerDashboard | null;
  if (!data) throw new Error('Unable to load owner dashboard: no dashboard data returned');
  return { dashboard: { ...data, attention: prioritizeAttention(data.attention ?? []) }, staff: staff.data ?? [], profile };
}
