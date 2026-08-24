'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';

async function rpc(name: string, values: Record<string, unknown>, path: string) {
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc(name, values);
  if (error) redirect(`${path}?error=${encodeURIComponent(error.message)}`);
  revalidatePath(path); revalidatePath('/owner');
}
const date = (value: FormDataEntryValue | null) => String(value || '') || null;
export async function decideApproval(form: FormData) { await rpc('decide_customer_approval',{p_customer_id:String(form.get('customerId')),p_status:String(form.get('status')),p_reason_notes:String(form.get('notes')||'')||null},'/operations/customers'); }
export async function setDocument(form: FormData) { await rpc('set_customer_document',{p_customer_id:String(form.get('customerId')),p_document_type:String(form.get('type')),p_status:String(form.get('status')),p_expiry_date:date(form.get('expiryDate'))},'/operations/customers'); }
export async function setCompliance(form: FormData) { await rpc('set_vehicle_compliance',{p_vehicle_id:String(form.get('vehicleId')),p_type:String(form.get('type')),p_status:String(form.get('status')),p_issued_at:date(form.get('issuedAt')),p_expires_at:date(form.get('expiresAt'))},'/operations/compliance'); }
export async function createPickup(form: FormData) { await rpc('create_pickup_checklist',{p_agreement_id:String(form.get('agreementId'))},'/operations/pickups'); }
export async function completePickup(form: FormData) { await rpc('complete_pickup',{p_checklist_id:String(form.get('checklistId')),p_odometer:Number(form.get('odometer'))},'/operations/pickups'); }
export async function createReturn(form: FormData) { await rpc('create_return_checklist',{p_assignment_id:String(form.get('assignmentId'))},'/operations/returns'); }
export async function completeReturn(form: FormData) { await rpc('complete_return',{p_checklist_id:String(form.get('checklistId')),p_odometer:Number(form.get('odometer')),p_condition:String(form.get('condition')),p_open_issue:form.get('openIssue')==='on',p_disposition:String(form.get('disposition'))},'/operations/returns'); }
export async function openJob(form: FormData) { await rpc('open_maintenance_job',{p_vehicle_id:String(form.get('vehicleId')),p_notes:String(form.get('notes')||'')||null,p_cost:null},'/operations/maintenance'); }
export async function completeJob(form: FormData) { const id=String(form.get('jobId')); await rpc('complete_maintenance_job',{p_job_id:id,p_odometer:Number(form.get('odometer')),p_notes:String(form.get('notes')||'')||null,p_cost:form.get('cost')?Number(form.get('cost')):null},`/operations/maintenance/${id}`); }
