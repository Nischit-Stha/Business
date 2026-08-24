'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';

const value = (form: FormData, key: string) => String(form.get(key) ?? '').trim();
const nullable = (form: FormData, key: string) => value(form, key) || null;

async function mutate(name: string, values: Record<string, unknown>, returnPath: string) {
  const { supabase } = await requireStaff();
  const { data, error } = await supabase.rpc(name, values);
  if (error) redirect(`${returnPath}?error=${encodeURIComponent(error.message)}`);
  revalidatePath('/operations/issues'); revalidatePath('/fleet'); revalidatePath('/owner');
  return data;
}

export async function createIssue(form: FormData) {
  const data = await mutate('create_vehicle_issue', { p_vehicle_id:value(form,'vehicleId'),p_customer_id:nullable(form,'customerId'),p_agreement_id:nullable(form,'agreementId'),p_severity:value(form,'severity'),p_category:value(form,'category'),p_description:value(form,'description'),p_assigned_to:nullable(form,'assignedTo') }, '/operations/issues/new');
  redirect(`/operations/issues/${data.id}`);
}
export async function assignIssue(form: FormData) { const id=value(form,'issueId'); await mutate('assign_vehicle_issue',{p_issue_id:id,p_assigned_to:value(form,'assignedTo')},`/operations/issues/${id}`); redirect(`/operations/issues/${id}`); }
export async function changeIssueStatus(form: FormData) { const id=value(form,'issueId'); await mutate('update_vehicle_issue_status',{p_issue_id:id,p_status:value(form,'status'),p_note:nullable(form,'note')},`/operations/issues/${id}`); redirect(`/operations/issues/${id}`); }
export async function addIssueNote(form: FormData) { const id=value(form,'issueId'); await mutate('add_vehicle_issue_note',{p_issue_id:id,p_note:value(form,'note')},`/operations/issues/${id}`); redirect(`/operations/issues/${id}`); }
export async function resolveIssue(form: FormData) { const id=value(form,'issueId'); await mutate('resolve_vehicle_issue',{p_issue_id:id,p_resolution:value(form,'resolution')},`/operations/issues/${id}`); redirect(`/operations/issues/${id}`); }
