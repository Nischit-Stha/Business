import 'server-only';

import { requireStaff } from '@/lib/auth';

export async function getAgreements(statuses: string[]) {
  const { supabase } = await requireStaff();
  const { data, error } = await supabase.from('agreements')
    .select('id, agreement_type, status, start_date, end_date, weekly_amount, customers(full_name), vehicles(registration)')
    .in('status', statuses).order('start_date', { ascending: false });
  if (error) throw new Error(`Unable to load agreements: ${error.message}`);
  return data ?? [];
}

export async function getAgreement(id: string) {
  const { supabase } = await requireStaff();
  const [agreement, schedule, payments, summary, progress, completion] = await Promise.all([
    supabase.from('agreements').select('*, customers(full_name), vehicles(registration, make, model)').eq('id', id).maybeSingle(),
    supabase.from('payment_schedule_items').select('*').eq('agreement_id', id).order('sequence_number'),
    supabase.from('payment_transactions').select('*').eq('agreement_id', id).order('received_at', { ascending: false }),
    supabase.from('agreement_payment_summary').select('*').eq('agreement_id', id).maybeSingle(),
    supabase.from('rent_to_own_progress').select('*').eq('agreement_id', id).maybeSingle(),
    supabase.from('rent_to_own_completion_readiness').select('*').eq('agreement_id', id).maybeSingle(),
  ]);
  const error = agreement.error ?? schedule.error ?? payments.error ?? summary.error ?? progress.error ?? completion.error;
  if (error) throw new Error(`Unable to load agreement: ${error.message}`);
  return { agreement: agreement.data, schedule: schedule.data ?? [], payments: payments.data ?? [], summary: summary.data, progress: progress.data, completion: completion.data };
}

export async function getAgreementFormOptions() {
  const { supabase } = await requireStaff();
  const [customers, assignments] = await Promise.all([
    supabase.from('customers').select('id, full_name').eq('status', 'ACTIVE').order('full_name'),
    supabase.from('vehicle_assignments').select('customer_id, vehicle_id, vehicles(registration, make, model)').eq('assignment_status', 'ACTIVE'),
  ]);
  if (customers.error || assignments.error) throw new Error('Unable to load agreement options.');
  return { customers: customers.data ?? [], assignments: assignments.data ?? [] };
}

export async function getPaymentsDashboard() {
  const { supabase } = await requireStaff();
  const columns='id,agreement_id,customer_name,registration,due_date,amount_due,amount_paid,outstanding,effective_status,overdue_days,reminder_state';
  const [due,overdue,upcoming,paid]=await Promise.all([
    supabase.from('payment_operations').select(columns).eq('effective_status','DUE').order('due_date').limit(250),
    supabase.from('payment_operations').select(columns).eq('effective_status','OVERDUE').order('due_date').limit(250),
    supabase.from('payment_operations').select(columns).eq('effective_status','UPCOMING').order('due_date').limit(100),
    supabase.from('payment_operations').select(columns).eq('effective_status','PAID').order('due_date',{ascending:false}).limit(100),
  ]);
  const error=due.error??overdue.error??upcoming.error??paid.error;if(error)throw new Error(`Unable to load payments: ${error.message}`);
  return{due:due.data??[],overdue:overdue.data??[],upcoming:upcoming.data??[],paid:paid.data??[]};
}
