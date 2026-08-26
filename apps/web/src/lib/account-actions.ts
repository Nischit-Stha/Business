'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireFreshAdmin } from '@/lib/auth';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { consumeActionBudget } from '@/lib/abuse-control';

const value=(form:FormData,key:string)=>String(form.get(key)??'').trim();
const fail=(message:string):never=>redirect(`/admin/accounts?error=${encodeURIComponent(message)}`);
const emailPattern=/^[^\s@]+@[^\s@]+\.[^\s@]+$/;
function appUrl(){const url=process.env.NEXT_PUBLIC_APP_URL;if(!url)throw new Error('NEXT_PUBLIC_APP_URL is required');return new URL(url).origin;}

export async function inviteAccount(form:FormData){
  const {supabase}=await requireFreshAdmin(); try{await consumeActionBudget(supabase,'INVITATION',20,3600);}catch(error){fail((error as Error).message);} const email=value(form,'email').toLowerCase(),accountType=value(form,'accountType'),fullName=value(form,'fullName'),customerId=value(form,'customerId')||null,staffRole=value(form,'staffRole')||null;
  if(!emailPattern.test(email)||!['STAFF','CUSTOMER'].includes(accountType)||!fullName||fullName.length>120)fail('Invalid invitation details');
  if((accountType==='CUSTOMER')!==Boolean(customerId))fail('Choose a customer for customer access');
  const admin=createSupabaseAdminClient();
  const invited=await admin.auth.admin.inviteUserByEmail(email,{redirectTo:`${appUrl()}/auth/callback?next=/account/setup`,data:{account_type:accountType}});
  const invitedUser=invited.data.user;
  if(invited.error||!invitedUser)fail('Unable to create or send invitation');
  const userId=invitedUser!.id;
  if(accountType==='STAFF'){
    const {error}=await admin.from('staff_profiles').upsert({user_id:userId,full_name:fullName,role:staffRole==='ADMIN'?'ADMIN':'STAFF',status:'ACTIVE',is_active:true});if(error)fail('Unable to provision staff access');
  }else{
    const {error}=await admin.from('customer_portal_accounts').upsert({user_id:userId,customer_id:customerId,status:'ACTIVE'});if(error)fail('Unable to provision portal access');
  }
  const expiry=new Date(Date.now()+24*60*60*1000).toISOString();
  const {error:auditError}=await supabase.rpc('record_invitation_created',{p_auth_user_id:userId,p_email:email,p_account_type:accountType,p_customer_id:customerId,p_staff_role:accountType==='STAFF'?(staffRole==='ADMIN'?'ADMIN':'STAFF'):null,p_expires_at:expiry});
  if(auditError)fail('Invitation created but audit recording failed');
  // Auth email delivery is handled by Supabase SMTP. Production config uses the documented Resend SMTP settings.
  revalidatePath('/admin/accounts');redirect('/admin/accounts?invited=1');
}

export async function setAccountEnabled(form:FormData){
  await requireFreshAdmin();const userId=value(form,'userId'),enabled=value(form,'enabled')==='true',accountType=value(form,'accountType');if(!/^[0-9a-f-]{36}$/.test(userId))fail('Invalid account');
  const admin=createSupabaseAdminClient();
  const table=accountType==='CUSTOMER'?'customer_portal_accounts':'staff_profiles';
  const changes=accountType==='CUSTOMER'?{status:enabled?'ACTIVE':'DISABLED'}:{status:enabled?'ACTIVE':'DISABLED',is_active:enabled};
  const {error}=await admin.from(table).update(changes).eq('user_id',userId);if(error)fail('Unable to change access');
  const {error:authError}=await admin.auth.admin.updateUserById(userId,{ban_duration:enabled?'none':'876000h'});if(authError)fail('Access changed but Auth disable failed');
  if(!enabled)await admin.auth.admin.signOut(userId,'global');
  revalidatePath('/admin/accounts');redirect('/admin/accounts?updated=1');
}

export async function resendInvitation(form:FormData){
  const {supabase}=await requireFreshAdmin();const id=value(form,'invitationId'),email=value(form,'email');
  if(!/^[0-9a-f-]{36}$/.test(id)||!emailPattern.test(email))fail('Invalid invitation');
  const {error}=await supabase.auth.resend({type:'signup',email,options:{emailRedirectTo:`${appUrl()}/auth/callback?next=/account/setup`}});if(error)fail('Invitation could not be resent');
  const {error:auditError}=await supabase.rpc('record_invitation_resent',{p_invitation_id:id,p_expires_at:new Date(Date.now()+24*60*60*1000).toISOString()});if(auditError)fail('Invitation sent but audit recording failed');
  revalidatePath('/admin/accounts');redirect('/admin/accounts?resent=1');
}

export async function requestPasswordRecovery(form:FormData){
  const email=value(form,'email').toLowerCase();
  if(emailPattern.test(email)){const supabase=await createSupabaseServerClient();await supabase.auth.resetPasswordForEmail(email,{redirectTo:`${appUrl()}/auth/callback?next=/account/reset-password`});}
  redirect('/forgot-password?sent=1');
}

export async function updatePassword(form:FormData){
  const password=value(form,'password'),confirm=value(form,'confirm');if(password!==confirm||password.length<12)redirect('/account/reset-password?error=Use%20a%20matching%20password%20of%20at%20least%2012%20characters');
  const supabase=await createSupabaseServerClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect('/login');
  const {error}=await supabase.auth.updateUser({password});if(error)redirect('/account/reset-password?error=Password%20could%20not%20be%20updated');
  await supabase.rpc('accept_current_invitation');await supabase.auth.signOut({scope:'others'});redirect('/login?message=Password%20updated');
}
