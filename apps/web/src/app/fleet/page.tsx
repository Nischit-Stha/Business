import Link from 'next/link';
import { getFleetOperations } from '@/lib/fleet';
import { StaffNav } from '@/components/staff-nav';

export const dynamic = 'force-dynamic';

const when = (value: string | null) => value ? new Date(value).toLocaleString('en-AU',{dateStyle:'short',timeStyle:'short'}) : '—';

export default async function FleetPage() {
  const vehicles = await getFleetOperations();
  const counts = { available:vehicles.filter(v=>v.operational_status==='AVAILABLE'&&v.ready_for_allocation).length,rented:vehicles.filter(v=>v.operational_status==='ASSIGNED').length,pickup:vehicles.filter(v=>v.next_pickup_at&&new Date(v.next_pickup_at).toDateString()===new Date().toDateString()).length,returns:vehicles.filter(v=>v.next_return_at&&new Date(v.next_return_at).toDateString()===new Date().toDateString()).length,workshop:vehicles.filter(v=>v.operational_status==='WORKSHOP').length,offroad:vehicles.filter(v=>v.operational_status==='OFF_ROAD').length,issues:vehicles.filter(v=>v.open_issue_count>0).length};
  return (
    <main>
      <StaffNav/>
      <p className="eyebrow">Operations</p>
      <h1>Fleet</h1>
      <Link className="primary-link" href="/fleet/new">Create vehicle</Link>
      <p className="lede">Current custody, readiness, scheduled movements, maintenance, and open issues.</p>
      <div className="summary-grid"><div><small>Ready available</small><strong>{counts.available}</strong></div><div><small>Rented</small><strong>{counts.rented}</strong></div><div><small>Pickup today</small><strong>{counts.pickup}</strong></div><div><small>Return today</small><strong>{counts.returns}</strong></div><div><small>Workshop</small><strong>{counts.workshop}</strong></div><div><small>Off-road</small><strong>{counts.offroad}</strong></div><div><small>With open issues</small><strong>{counts.issues}</strong></div></div>
      <div className="table-wrap"><table>
        <thead><tr><th>Registration</th><th>Vehicle</th><th>Status</th><th>Current customer</th><th>Agreement</th><th>Next pickup</th><th>Next return</th><th>Issues</th><th>Maintenance</th><th>Allocation</th></tr></thead>
        <tbody>{vehicles.map((vehicle) => <tr key={vehicle.id}><td><Link href={`/fleet/${vehicle.id}`}><strong>{vehicle.registration}</strong></Link></td><td>{vehicle.year} {vehicle.make} {vehicle.model}</td><td><span className={`status status-${vehicle.operational_status.toLowerCase()}`}>{vehicle.operational_status.replaceAll('_',' ')}</span></td><td>{vehicle.current_customer??'—'}</td><td>{vehicle.agreement_id?<Link href={`/agreements/${vehicle.agreement_id}`}>{vehicle.agreement_status}</Link>:'—'}</td><td>{when(vehicle.next_pickup_at)}</td><td>{when(vehicle.next_return_at)}</td><td>{vehicle.open_issue_count?<Link href={`/operations/issues?vehicle=${vehicle.id}`}>{vehicle.open_issue_count} open</Link>:'None'}</td><td>{vehicle.maintenance_status??'Not configured'}</td><td>{vehicle.ready_for_allocation?'Ready':'Not ready'}</td></tr>)}</tbody>
      </table></div>
      {vehicles.length === 0 && <p className="empty">No fleet data is available to this session.</p>}
    </main>
  );
}
