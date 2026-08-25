import { getFleetOperations } from '@/lib/fleet';
import { StaffNav } from '@/components/staff-nav';
import { FleetBoard } from '@/components/fleet-board';
import { ActionButton, MetricCard, PageHeader } from '@/components/ui';

export const dynamic = 'force-dynamic';

export default async function FleetPage() {
  const vehicles = await getFleetOperations();
  const counts = { available:vehicles.filter(v=>v.operational_status==='AVAILABLE'&&v.ready_for_allocation).length,rented:vehicles.filter(v=>v.operational_status==='ASSIGNED').length,pickup:vehicles.filter(v=>v.next_pickup_at&&new Date(v.next_pickup_at).toDateString()===new Date().toDateString()).length,returns:vehicles.filter(v=>v.next_return_at&&new Date(v.next_return_at).toDateString()===new Date().toDateString()).length,workshop:vehicles.filter(v=>v.operational_status==='WORKSHOP').length,offroad:vehicles.filter(v=>v.operational_status==='OFF_ROAD').length,issues:vehicles.filter(v=>v.open_issue_count>0).length};
  return (
    <main id="main-content">
      <StaffNav/>
      <PageHeader eyebrow="Fleet operations" title="Fleet" description="Readiness, custody and next movements across every vehicle." actions={<ActionButton href="/fleet/new">Add vehicle</ActionButton>}/>
      <div className="summary-grid"><MetricCard label="Ready & available" value={counts.available} tone="positive"/><MetricCard label="Rented" value={counts.rented}/><MetricCard label="Pickup today" value={counts.pickup}/><MetricCard label="Return today" value={counts.returns}/><MetricCard label="Workshop / off road" value={counts.workshop+counts.offroad} tone={counts.workshop+counts.offroad?'warning':'default'}/><MetricCard label="With open issues" value={counts.issues} tone={counts.issues?'danger':'default'}/></div>
      <FleetBoard vehicles={vehicles}/>
    </main>
  );
}
