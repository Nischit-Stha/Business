'use server';
import { revalidatePath } from 'next/cache';import { redirect } from 'next/navigation';import { requireStaff } from '@/lib/auth';
const v=(f:FormData,k:string)=>String(f.get(k)??'').trim();
async function call(name:string,args:Record<string,unknown>){const {supabase}=await requireStaff();const {error}=await supabase.rpc(name,args);if(error)redirect(`/operations/portal-requests?error=${encodeURIComponent(error.message)}`);revalidatePath('/operations/portal-requests');}
export async function assignPortalRequest(f:FormData){await call('assign_portal_request',{p_request_id:v(f,'requestId'),p_staff_id:v(f,'staffId')});}
export async function decidePortalRequest(f:FormData){await call('decide_portal_request',{p_request_id:v(f,'requestId'),p_decision:v(f,'decision'),p_response:v(f,'response'),p_resolution_reason:v(f,'reason')||null});}
export async function completePortalRequest(f:FormData){await call('complete_portal_request',{p_request_id:v(f,'requestId'),p_response:v(f,'response')||null});}
