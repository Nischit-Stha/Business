import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';

export default async function IssuesPage({ searchParams }: { searchParams: Promise<{ vehicle?: string }> }) {
  const { vehicle } = await searchParams; const { supabase } = await requireStaff();
  let query = supabase.from('vehicle_issues').select('id,severity,category,status,description,created_at,vehicles(registration,make,model),staff_profiles!vehicle_issues_assigned_to_fkey(full_name)').order('created_at',{ascending:false});
  if(vehicle) query=query.eq('vehicle_id',vehicle); const {data,error}=await query; if(error) throw new Error(`Unable to load vehicle issues: ${error.message}`);
  const open=data?.filter(i=>!['RESOLVED','CANCELLED'].includes(i.status))??[]; const closed=data?.filter(i=>['RESOLVED','CANCELLED'].includes(i.status))??[];
  const table=(rows:typeof open,empty:string)=>rows.length===0?<p className="empty-state">{empty}</p>:<div className="table-wrap"><table><thead><tr><th>Priority</th><th>Vehicle</th><th>Issue</th><th>Status</th><th>Assigned</th><th>Created</th></tr></thead><tbody>{rows.map(i=><tr key={i.id}><td><span className={`status severity-${i.severity.toLowerCase()}`}>{i.severity}</span></td><td>{i.vehicles?.[0]?.registration}<br/><span className="table-detail">{i.vehicles?.[0]?.make} {i.vehicles?.[0]?.model}</span></td><td><Link href={`/operations/issues/${i.id}`}><strong>{i.category.replaceAll('_',' ')}</strong></Link><br/><span className="table-detail">{i.description}</span></td><td>{i.status.replaceAll('_',' ')}</td><td>{i.staff_profiles?.[0]?.full_name??'Unassigned'}</td><td>{new Date(i.created_at).toLocaleDateString('en-AU')}</td></tr>)}</tbody></table></div>;
  return <main><StaffNav/><p className="eyebrow">Fleet operations</p><h1>Vehicle issues</h1><p className="lede">Track ownership, progress, notes, and resolution without losing history.</p><Link className="primary-link" href="/operations/issues/new">Report issue</Link><section className="dashboard-section"><h2>Active issues</h2>{table(open,'No active vehicle issues.')}</section><section className="dashboard-section"><h2>Resolved / cancelled</h2>{table(closed,'No closed vehicle issues.')}</section></main>;
}
