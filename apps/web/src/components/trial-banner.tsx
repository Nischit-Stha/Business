import { readRuntimeMode } from '@/lib/env';
export function TrialBanner(){const mode=readRuntimeMode();if(mode==='production')return null;return <div className="trial-banner" role="status"><strong>{mode==='trial'?'TRIAL / STAGING':'LOCAL DEVELOPMENT'}</strong> · Synthetic test data only · External providers disabled by default</div>}
