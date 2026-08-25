import { timingSafeEqual } from 'node:crypto';
import { NextResponse } from 'next/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

export const runtime='nodejs';
function authorized(request:Request){const configured=process.env.SCHEDULER_SECRET??'',provided=request.headers.get('authorization')?.replace(/^Bearer\s+/,'')??'';if(configured.length<32||provided.length!==configured.length)return false;return timingSafeEqual(Buffer.from(provided),Buffer.from(configured));}
export async function POST(request:Request){
 if(!authorized(request))return NextResponse.json({error:'Unauthorized'},{status:401,headers:{'Cache-Control':'no-store'}});
 const actor=process.env.SCHEDULER_ACTOR_USER_ID;if(!actor)return NextResponse.json({error:'Scheduler is not configured'},{status:503});
 const requestId=(request.headers.get('x-request-id')??crypto.randomUUID()).slice(0,100);
 const admin=createSupabaseAdminClient();const {data,error}=await admin.rpc('run_due_scheduled_jobs_scheduler',{p_actor:actor,p_limit:8});
 if(error)return NextResponse.json({error:'Scheduler execution failed',requestId},{status:500,headers:{'Cache-Control':'no-store'}});
 return NextResponse.json({requestId,executions:data?.map((row:{id:string;job_key:string;status:string;duration_ms:number|null})=>({id:row.id,jobKey:row.job_key,status:row.status,durationMs:row.duration_ms}))??[]},{headers:{'Cache-Control':'no-store'}});
}
export function GET(){return NextResponse.json({error:'Method not allowed'},{status:405,headers:{Allow:'POST'}})}
