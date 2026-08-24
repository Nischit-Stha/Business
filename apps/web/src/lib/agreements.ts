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
  const [agreement, schedule, payments, summary, progress] = await Promise.all([
    supabase.from('agreements').select('*, customers(full_name), vehicles(registration, make, model)').eq('id', id).maybeSingle(),
    supabase.from('payment_schedule_items').select('*').eq('agreement_id', id).order('sequence_number'),
    supabase.from('payment_transactions').select('*').eq('agreement_id', id).order('received_at', { ascending: false }),
    supabase.from('agreement_payment_summary').select('*').eq('agreement_id', id).maybeSingle(),
    supabase.from('rent_to_own_progress').select('*').eq('agreement_id', id).maybeSingle(),
  ]);
  const error = agreement.error ?? schedule.error ?? payments.error ?? summary.error ?? progress.error;
  if (error) throw new Error(`Unable to load agreement: ${error.message}`);
  return { agreement: agreement.data, schedule: schedule.data ?? [], payments: payments.data ?? [], summary: summary.data, progress: progress.data };
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
  const { data, error } = await supabase.from('payment_schedule_items')
    .select('id, agreement_id, due_date, amount_due, amount_paid, status, agreements(customers(full_name), vehicles(registration))')
    .order('due_date');
  if (error) throw new Error(`Unable to load payments: ${error.message}`);
  const items = data ?? [];
  const today = new Date().toISOString().slice(0, 10);
  return {
    due: items.filter((x) => x.due_date === today && x.amount_paid < x.amount_due && x.status !== 'WAIVED'),
    overdue: items.filter((x) => x.due_date < today && x.amount_paid < x.amount_due && x.status !== 'WAIVED'),
    upcoming: items.filter((x) => x.due_date > today && x.amount_paid < x.amount_due && x.status !== 'WAIVED'),
    paid: items.filter((x) => x.amount_paid >= x.amount_due || x.status === 'WAIVED').reverse(),
  };
}
