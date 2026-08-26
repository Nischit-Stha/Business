const LOCAL_PLACEHOLDER = 'replace-with-local-anon-key';

export type PublicEnvironment = {
  supabaseUrl: string;
  supabaseAnonKey: string;
};

export type PrivateEnvironment = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
};

export type RuntimeMode = 'development' | 'trial' | 'production';

export type ReadinessState = {
  environment: RuntimeMode;
  databaseConfigured: boolean;
  externalProviders: 'disabled' | 'enabled';
  email: 'local-only' | 'configured' | 'misconfigured';
  scheduler: 'configured' | 'not configured';
  mfaPolicy: 'optional' | 'admin rollout' | 'admin required';
  backupVerification: 'verified' | 'not verified';
  uploadScanning: 'configured' | 'unavailable';
  deploymentVersion: string;
  migrationVersion: string;
};

export function getReadinessState(environment: Readonly<Record<string, string | undefined>> = process.env): ReadinessState {
  const mode = readRuntimeMode(environment);
  const emailProvider = environment.EMAIL_PROVIDER ?? 'LOCAL';
  return {
    environment: mode,
    databaseConfigured: Boolean(environment.NEXT_PUBLIC_SUPABASE_URL && environment.SUPABASE_SERVICE_ROLE_KEY),
    externalProviders: environment.ALLOW_EXTERNAL_PROVIDERS === 'true' ? 'enabled' : 'disabled',
    email: emailProvider === 'LOCAL' ? 'local-only' : environment.RESEND_API_KEY && environment.EMAIL_FROM ? 'configured' : 'misconfigured',
    scheduler: environment.SCHEDULER_SECRET && environment.SCHEDULER_ACTOR_USER_ID ? 'configured' : 'not configured',
    mfaPolicy: environment.ADMIN_MFA_ENFORCEMENT === 'required' ? 'admin required' : mode === 'development' ? 'optional' : 'admin rollout',
    backupVerification: environment.STAGING_BACKUP_VERIFIED_AT ? 'verified' : 'not verified',
    uploadScanning: environment.UPLOAD_SCANNER === 'configured' ? 'configured' : 'unavailable',
    deploymentVersion: environment.DEPLOYMENT_VERSION ?? 'unknown',
    migrationVersion: environment.MIGRATION_VERSION ?? 'unknown',
  };
}

export function readRuntimeMode(environment: Readonly<Record<string, string | undefined>> = process.env): RuntimeMode {
  const value = environment.VEERA_RUNTIME_MODE ?? 'development';
  if (!['development', 'trial', 'production'].includes(value)) throw new Error('VEERA_RUNTIME_MODE must be development, trial, or production.');
  return value as RuntimeMode;
}

export function assertProviderAllowed(provider: string, environment: Readonly<Record<string, string | undefined>> = process.env) {
  const mode = readRuntimeMode(environment);
  if (mode !== 'production' && provider !== 'LOCAL' && environment.ALLOW_EXTERNAL_PROVIDERS !== 'true') {
    throw new Error('External providers are disabled outside production unless ALLOW_EXTERNAL_PROVIDERS=true.');
  }
}

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

export function readPrivateEnvironment(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): PrivateEnvironment {
  const supabaseUrl = environment.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseServiceRoleKey = environment.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !supabaseServiceRoleKey || supabaseServiceRoleKey === 'replace-with-local-service-role-key') {
    throw new Error('Server-only SUPABASE_SERVICE_ROLE_KEY must contain a local or staging value.');
  }
  return { supabaseUrl, supabaseServiceRoleKey };
}
