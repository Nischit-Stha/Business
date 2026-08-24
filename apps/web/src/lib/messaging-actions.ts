'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';
import { runDeliveryWorker } from '@/lib/messaging-worker';

const value=(form:FormData,key:string)=>String(form.get(key)??'').trim();
const fail=(message:string):never=>redirect(`/messaging?error=${encodeURIComponent(message)}`);

export async function processMessages(){const {supabase}=await requireStaff();try{await runDeliveryWorker(supabase,25);}catch(error){fail(error instanceof Error?error.message:'Worker failed');}revalidatePath('/messaging');redirect('/messaging');}
export async function generateMessages(){const {supabase}=await requireStaff();const {error}=await supabase.rpc('generate_message_reminders',{});if(error)fail(error.message);revalidatePath('/messaging');redirect('/messaging');}
export async function retryMessage(form:FormData){const {supabase}=await requireStaff();const {error}=await supabase.rpc('retry_message_delivery',{p_delivery_id:value(form,'deliveryId')});if(error)fail(error.message);revalidatePath('/messaging');redirect('/messaging');}
export async function cancelMessage(form:FormData){const {supabase}=await requireStaff();const {error}=await supabase.rpc('cancel_message_delivery',{p_delivery_id:value(form,'deliveryId')});if(error)fail(error.message);revalidatePath('/messaging');redirect('/messaging');}
