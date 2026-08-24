'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function signIn(form: FormData) {
  const supabase = await createSupabaseServerClient();
  const email = String(form.get('email') ?? '').trim();
  const password = String(form.get('password') ?? '');
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) redirect('/login?error=Invalid%20email%20or%20password');
  redirect('/fleet');
}

export async function signOut() {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect('/login');
}
