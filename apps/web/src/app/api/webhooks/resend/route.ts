import { Webhook } from 'svix';
import { NextResponse } from 'next/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
export const runtime='nodejs';
type ResendEvent={type:string;data?:{email_id?:string}};
export async function POST(request:Request){
 const secret=process.env.RESEND_WEBHOOK_SECRET;if(!secret)return NextResponse.json({error:'Webhook not configured'},{status:503});
 const body=await request.text();let event:ResendEvent;
 try{event=new Webhook(secret).verify(body,{'svix-id':request.headers.get('svix-id')??'','svix-timestamp':request.headers.get('svix-timestamp')??'','svix-signature':request.headers.get('svix-signature')??''}) as ResendEvent;}catch{return NextResponse.json({error:'Invalid signature'},{status:401});}
 if(event.type==='email.delivered'&&event.data?.email_id){const {error}=await createSupabaseAdminClient().rpc('record_provider_delivery_receipt',{p_provider_message_id:event.data.email_id});if(error&&error.code!=='P0001')return NextResponse.json({error:'Receipt processing failed'},{status:500});}
 return NextResponse.json({received:true});
}
