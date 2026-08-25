import { NextResponse } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function GET(request:Request){
  const url=new URL(request.url),code=url.searchParams.get('code'),next=url.searchParams.get('next')??'/';
  const safeNext=/^\/(account\/(setup|reset-password)|portal|fleet)$/.test(next)?next:'/';
  if(code){const supabase=await createSupabaseServerClient();const {error}=await supabase.auth.exchangeCodeForSession(code);if(!error)return NextResponse.redirect(new URL(safeNext,url.origin));}
  return NextResponse.redirect(new URL('/login?error=Authentication%20link%20is%20invalid%20or%20expired',url.origin));
}
