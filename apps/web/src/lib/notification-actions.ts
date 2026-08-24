'use server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';
import { runNotificationWorker } from '@/lib/notification-worker';

const field=(form:FormData,key:string)=>String(form.get(key)??'').trim();
const fail=(message:string):never=>redirect(`/notifications?error=${encodeURIComponent(message)}`);
export async function generateNotifications(){const {supabase}=await requireStaff();const {error}=await supabase.rpc('generate_notifications',{});if(error)fail(error.message);revalidatePath('/notifications');redirect('/notifications');}
export async function processNotifications(){const {supabase}=await requireStaff();try{await runNotificationWorker(supabase,25);}catch(e){fail(e instanceof Error?e.message:'Worker failed');}revalidatePath('/notifications');redirect('/notifications');}
export async function retryNotification(form:FormData){const {supabase}=await requireStaff();const {error}=await supabase.rpc('retry_notification',{p_id:field(form,'id')});if(error)fail(error.message);revalidatePath('/notifications');redirect('/notifications');}
export async function cancelNotification(form:FormData){const {supabase}=await requireStaff();const {error}=await supabase.rpc('cancel_notification',{p_id:field(form,'id')});if(error)fail(error.message);revalidatePath('/notifications');redirect('/notifications');}
export async function manuallyQueueNotification(form:FormData){const {supabase}=await requireStaff();const {error}=await supabase.rpc('queue_supported_notification',{p_type:field(form,'type'),p_customer_id:field(form,'customerId'),p_vehicle_id:field(form,'vehicleId')||null,p_agreement_id:null,p_issue_id:null});if(error)fail(error.message);revalidatePath('/notifications');redirect('/notifications');}
