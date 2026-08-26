export type ScanResult = { verdict: 'clean' | 'rejected' | 'unavailable'; reason: string };

/** Provider boundary. Development uses only structural checks; trial/production fail closed without a scanner. */
export async function scanUpload(_bytes: Uint8Array, environment: Readonly<Record<string,string|undefined>>=process.env):Promise<ScanResult>{
  if ((environment.VEERA_RUNTIME_MODE ?? 'development') === 'development') return {verdict:'clean',reason:'development-structural-validation'};
  if (environment.UPLOAD_SCANNER !== 'configured') return {verdict:'unavailable',reason:'scanner-not-configured'};
  // No provider is wired yet. Never return clean merely because configuration says one exists.
  return {verdict:'unavailable',reason:'scanner-adapter-not-implemented'};
}
