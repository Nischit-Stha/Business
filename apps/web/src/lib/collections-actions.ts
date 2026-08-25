'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createHash } from 'node:crypto';
import { requireStaff } from '@/lib/auth';
import { parseTollFineCsv } from '@/lib/toll-fine-csv';

const value = (form: FormData, key: string) => String(form.get(key) ?? '').trim();
function fail(path: string, message: string): never { redirect(`${path}?error=${encodeURIComponent(message)}`); }

export async function createNotice(form: FormData) {
  const { supabase } = await requireStaff();
  const path = '/operations/tolls-fines';
  const { data, error } = await supabase.rpc('create_toll_fine_notice', {
    p_notice_type: value(form, 'noticeType'), p_external_reference: value(form, 'externalReference') || null,
    p_vehicle_id: value(form, 'vehicleId'), p_registration_snapshot: value(form, 'registrationSnapshot'),
    p_occurred_at: value(form, 'occurredAt'), p_issued_at: value(form, 'issuedAt') || null,
    p_amount: Number(value(form, 'amount')), p_source: 'MANUAL', p_authority_provider: value(form, 'authorityProvider') || null,
    p_notes: value(form, 'notes') || null,
  });
  if (error) fail(path, error.message);
  revalidatePath(path); redirect(`/operations/tolls-fines/${data.id}`);
}

export async function reviewNotice(form: FormData) {
  const id = value(form, 'noticeId'); const path = `/operations/tolls-fines/${id}`; const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('review_notice_allocation', { p_notice_id: id, p_decision: value(form, 'decision'), p_customer_id: value(form, 'customerId') || null, p_assignment_id: value(form, 'assignmentId') || null, p_reason: value(form, 'reason') });
  if (error) fail(path, error.message); revalidatePath(path); revalidatePath('/operations/tolls-fines'); redirect(path);
}

export async function transitionNotice(form: FormData) {
  const id=value(form,'noticeId'); const path=`/operations/tolls-fines/${id}`; const {supabase}=await requireStaff();
  const {error}=await supabase.rpc('transition_toll_fine_notice',{p_notice_id:id,p_status:value(form,'status'),p_reason:value(form,'reason')});
  if(error) fail(path,error.message); revalidatePath(path); redirect(path);
}

export async function importTollFineCsv(form: FormData){
  const path='/operations/tolls-fines';const {supabase}=await requireStaff();const file=form.get('file');
  if(!(file instanceof File)||!file.name.toLowerCase().endsWith('.csv')||!['text/csv','application/vnd.ms-excel',''].includes(file.type))fail(path,'Choose a CSV file.');
  if(file.size>512_000)fail(path,'CSV must be 500 KB or smaller.');
  const bytes=Buffer.from(await file.arrayBuffer());let rows:Record<string,string>[];
  try{rows=parseTollFineCsv(bytes.toString('utf8'));}catch(error){fail(path,error instanceof Error?error.message:'Invalid CSV.');}
  const checksum=createHash('sha256').update(bytes).digest('hex');
  const {data,error}=await supabase.rpc('import_synthetic_toll_fine_csv',{p_source:'SYNTHETIC_CSV',p_file_name:file.name,p_checksum:checksum,p_rows:rows});
  if(error)fail(path,error.message);revalidatePath(path);revalidatePath('/owner');redirect(`${path}?batch=${data.id}`);
}

export async function logCommunication(form: FormData) {
  const customerId=value(form,'customerId'); const returnPath=value(form,'returnPath')||`/customers/${customerId}`; const {supabase}=await requireStaff();
  const {error}=await supabase.rpc('log_communication',{p_customer_id:customerId,p_agreement_id:value(form,'agreementId')||null,p_vehicle_id:value(form,'vehicleId')||null,p_channel:value(form,'channel'),p_direction:value(form,'direction'),p_type:value(form,'communicationType'),p_status:value(form,'status'),p_outcome:value(form,'outcome')||null,p_summary:value(form,'summary'),p_occurred_at:value(form,'occurredAt')});
  if(error) fail(returnPath,error.message); revalidatePath(returnPath); redirect(returnPath);
}

export async function createPromise(form: FormData) {
  const path='/collections'; const {supabase}=await requireStaff(); const {error}=await supabase.rpc('create_payment_promise',{p_agreement_id:value(form,'agreementId'),p_amount:Number(value(form,'amount')),p_date:value(form,'date'),p_note:value(form,'note')||null});
  if(error) fail(path,error.message); revalidatePath(path); redirect(path);
}

export async function changePromise(form: FormData) {
  const path='/collections'; const {supabase}=await requireStaff(); const {error}=await supabase.rpc('change_payment_promise',{p_promise_id:value(form,'promiseId'),p_status:value(form,'status'),p_note:value(form,'note')||null});
  if(error) fail(path,error.message); revalidatePath(path); redirect(path);
}

export async function generateReminders() {
  const path='/collections'; const {supabase}=await requireStaff(); const {error}=await supabase.rpc('run_collection_workflows',{});
  if(error) fail(path,error.message); revalidatePath(path); revalidatePath('/owner'); redirect(path);
}
