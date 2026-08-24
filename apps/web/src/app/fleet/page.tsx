import Link from 'next/link';
import { getFleet } from '@/lib/fleet';
import { StaffNav } from '@/components/staff-nav';

export const dynamic = 'force-dynamic';

function movement(status: string) {
  if (status === 'PICKUP_PENDING') return 'Pickup pending';
  if (status === 'RETURN_PENDING') return 'Return pending';
  return '—';
}

export default async function FleetPage() {
  const vehicles = await getFleet();
  return (
    <main>
      <StaffNav/>
      <p className="eyebrow">Operations</p>
      <h1>Fleet</h1>
      <Link className="primary-link" href="/fleet/new">Create vehicle</Link>
      <p className="lede">Current custody and movement state. Data is read through the signed-in staff session.</p>
      <div className="table-wrap"><table>
        <thead><tr><th>Registration</th><th>Vehicle</th><th>Status</th><th>Current customer</th><th>Pickup / return</th></tr></thead>
        <tbody>{vehicles.map((vehicle) => {
          const active = vehicle.vehicle_assignments[0];
          return <tr key={vehicle.id}><td><Link href={`/fleet/${vehicle.id}`}><strong>{vehicle.registration}</strong></Link></td><td>{vehicle.year} {vehicle.make} {vehicle.model}</td><td><span className={`status status-${vehicle.operational_status.toLowerCase()}`}>{vehicle.operational_status.replaceAll('_', ' ')}</span></td><td>{active?.customers[0]?.full_name ?? '—'}</td><td>{movement(vehicle.operational_status)}</td></tr>;
        })}</tbody>
      </table></div>
      {vehicles.length === 0 && <p className="empty">No fleet data is available to this session.</p>}
    </main>
  );
}
