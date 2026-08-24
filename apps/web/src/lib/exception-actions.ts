'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';

function value(form: FormData, key: string) { return String(form.get(key) ?? '').trim(); }
function fail(message: string): never { redirect(`/owner?error=${encodeURIComponent(message)}`); }

export async function assignException(form: FormData) {
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('assign_exception', { p_exception_id: value(form, 'id'), p_assigned_to: value(form, 'assignedTo') });
  if (error) fail(error.message);
  revalidatePath('/owner'); redirect('/owner');
}

export async function resolveException(form: FormData) {
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('resolve_exception', { p_exception_id: value(form, 'id'), p_resolution_note: value(form, 'resolutionNote') });
  if (error) fail(error.message);
  revalidatePath('/owner'); redirect('/owner');
}

export async function extendOpenSchedules() {
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('run_open_agreement_schedule_extension', { p_future_weeks: 12 });
  if (error) fail(error.message);
  revalidatePath('/owner'); redirect('/owner');
}
