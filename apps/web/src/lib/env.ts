const LOCAL_PLACEHOLDER = 'replace-with-local-anon-key';

export type PublicEnvironment = {
  supabaseUrl: string;
  supabaseAnonKey: string;
};

export function readPublicEnvironment(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): PublicEnvironment {
  const supabaseUrl = environment.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = environment.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey || supabaseAnonKey === LOCAL_PLACEHOLDER) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY must contain local or staging values.',
    );
  }

  return { supabaseUrl, supabaseAnonKey };
}
