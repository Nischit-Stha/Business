import { StaffNav } from '@/components/staff-nav';
import { requireAdmin } from '@/lib/auth';
import { getReadinessState } from '@/lib/env';
export default async function EnvironmentPage(){await requireAdmin();const state=getReadinessState();const rows=Object.entries(state).map(([key,value])=>[key.replaceAll(/([A-Z])/g,' $1'),String(value)]);return <><StaffNav/><main className="page-shell"><h1>Staging deployment readiness</h1><p>Administrator-only configuration state. Secret values, project references, storage paths, and provider responses are never rendered.</p><dl>{rows.map(([key,value])=><div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl><p>This page is evidence support, not a health guarantee. Verify backup restore and external controls independently.</p></main></>}
