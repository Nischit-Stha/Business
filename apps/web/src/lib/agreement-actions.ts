'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';

function fail(path: string, message: string): never { redirect(`${path}?error=${encodeURIComponent(message)}`); }
function value(form: FormData, name: string) { return String(form.get(name) ?? '').trim(); }
function optional(form: FormData, name: string) { return value(form, name) || null; }
function amount(form: FormData, name: string) { const parsed = Number(value(form, name)); return Number.isFinite(parsed) ? parsed : NaN; }

export async function createAgreement(form: FormData) {
  const path = '/agreements/new';
  const weeklyAmount = amount(form, 'weeklyAmount');
  if (!(weeklyAmount > 0)) fail(path, 'Weekly amount must be greater than zero.');
  const { supabase } = await requireStaff();
  const { data, error } = await supabase.rpc('create_agreement', {
    p_customer_id: value(form, 'customerId'), p_vehicle_id: value(form, 'vehicleId'),
    p_agreement_type: value(form, 'agreementType'), p_start_date: value(form, 'startDate'),
    p_end_date: optional(form, 'endDate'), p_first_due_date: value(form, 'firstDueDate'),
    p_weekly_amount: weeklyAmount, p_deposit_amount: amount(form, 'depositAmount') || 0,
    p_agreed_total_amount: optional(form, 'agreedTotalAmount') ? amount(form, 'agreedTotalAmount') : undefined,
    p_agreed_payment_count: optional(form, 'agreedPaymentCount') ? Number(value(form, 'agreedPaymentCount')) : undefined,
    p_external_contract_provider: optional(form, 'externalContractProvider'),
    p_external_contract_id: optional(form, 'externalContractId'),
  });
  if (error) fail(path, error.message);
  const agreement = Array.isArray(data) ? data[0] : data;
  revalidatePath('/agreements'); redirect(`/agreements/${agreement.id}`);
}

export async function transitionAgreement(form: FormData) {
  const id = value(form, 'id');
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('transition_agreement', { p_agreement_id: id, p_new_status: value(form, 'status') });
  if (error) fail(`/agreements/${id}`, error.message);
  revalidatePath('/agreements'); revalidatePath(`/agreements/${id}`); revalidatePath('/payments');
  redirect(`/agreements/${id}`);
}

export async function recordPayment(form: FormData) {
  const agreementId = value(form, 'agreementId');
  const path = `/agreements/${agreementId}`;
  const paymentAmount = amount(form, 'amount');
  if (!(paymentAmount > 0)) fail(path, 'Payment amount must be greater than zero.');
  const received = value(form, 'receivedAt');
  const receivedAt = new Date(received).toISOString();
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('record_manual_payment', {
    p_agreement_id: agreementId, p_amount: paymentAmount, p_received_at: receivedAt,
    p_reference: optional(form, 'reference'), p_notes: optional(form, 'notes'),
  });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath('/payments'); redirect(path);
}

export async function extendSchedule(form: FormData) {
  const id = value(form, 'id');
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('generate_payment_schedule', { p_agreement_id: id, p_through_date: value(form, 'throughDate') });
  if (error) fail(`/agreements/${id}`, error.message);
  revalidatePath(`/agreements/${id}`); redirect(`/agreements/${id}`);
}

export async function reversePayment(form: FormData) {
  const agreementId = value(form, 'agreementId');
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('reverse_manual_payment', { p_payment_transaction_id: value(form, 'paymentId'), p_reason: value(form, 'reason') });
  if (error) fail(`/agreements/${agreementId}`, error.message);
  revalidatePath(`/agreements/${agreementId}`); revalidatePath('/payments'); redirect(`/agreements/${agreementId}`);
}
