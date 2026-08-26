import { StaffNav } from '@/components/staff-nav';
import { StatusBadge } from '@/components/ui';
import { requireStaff } from '@/lib/auth';
import { completePickup, schedulePickup } from '@/lib/operations-actions';
const friendly = (value: string) =>
  value
    .replaceAll('_', ' ')
    .toLowerCase()
    .replace(/^./, (c) => c.toUpperCase());
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { supabase } = await requireStaff();
  const { error } = await searchParams;
  const [
    { data: agreements },
    { data: items },
    { data: readiness },
    { data: customers },
    { data: issues },
  ] = await Promise.all([
    supabase
      .from('agreements')
      .select('id,status,customers(full_name),vehicles(registration)')
      .in('status', ['PENDING_SIGNATURE', 'ACTIVE'])
      .order('created_at', { ascending: false }),
    supabase
      .from('pickup_checklists')
      .select(
        '*,agreements(status),customers(full_name),vehicles(registration,odometer)',
      )
      .not('status', 'in', '(COMPLETED,CANCELLED)')
      .order('scheduled_at'),
    supabase
      .from('vehicle_operational_detail')
      .select(
        'vehicle_id,readiness_blockers,maintenance_status,registration_status,rwc_status',
      ),
    supabase.from('customer_readiness').select('*'),
    supabase
      .from('vehicle_issues')
      .select('vehicle_id,severity,category,status')
      .not('status', 'in', '(RESOLVED,CANCELLED)'),
  ]);
  return (
    <main>
      <StaffNav />
      <p className="eyebrow">Physical handover</p>
      <h1>Pickup handovers</h1>
      <p className="lede">
        Scheduling plans the handover. Custody starts only after every blocker
        is clear and staff confirm the keys and vehicle were handed over.
      </p>
      {error && (
        <p className="error" role="alert">
          <strong>Pickup was not completed.</strong> {error}
        </p>
      )}
      <section className="dashboard-section">
        <h2>Schedule a pickup</h2>
        <form action={schedulePickup} className="form-card">
          <label>
            Agreement
            <select name="agreementId" required>
              <option value="">Select agreement</option>
              {agreements?.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.customers?.[0]?.full_name} —{' '}
                  {a.vehicles?.[0]?.registration} ({friendly(a.status)})
                </option>
              ))}
            </select>
          </label>
          <label>
            Scheduled time
            <input name="scheduledAt" type="datetime-local" required />
          </label>
          <label>
            Staff notes
            <textarea name="notes" maxLength={2000} />
          </label>
          <button>Schedule pickup</button>
        </form>
      </section>
      <section className="dashboard-section">
        <h2>Planned pickups</h2>
        <div className="workflow-grid">
          {items?.map((i) => {
            const vehicle = i.vehicles?.[0],
              customer = i.customers?.[0],
              agreement = i.agreements?.[0],
              vehicleState = readiness?.find(
                (r) => r.vehicle_id === i.vehicle_id,
              ),
              customerState = customers?.find(
                (r) => r.customer_id === i.customer_id,
              ),
              openIssues =
                issues?.filter((x) => x.vehicle_id === i.vehicle_id) ?? [];
            const blockers = [
              ...(vehicleState?.readiness_blockers ?? []),
              ...(!customerState?.ready
                ? ['Customer approval or required documents are incomplete']
                : []),
              ...(agreement?.status !== 'ACTIVE'
                ? ['Agreement is not active']
                : []),
            ];
            return (
              <article className="section-card" key={i.id}>
                <div className="section-card-header">
                  <div>
                    <h3>
                      {vehicle?.registration} · {customer?.full_name}
                    </h3>
                    <p>
                      {i.scheduled_at
                        ? new Date(i.scheduled_at).toLocaleString('en-AU')
                        : 'Not scheduled'}
                    </p>
                  </div>
                  <StatusBadge status={blockers.length ? 'BLOCKED' : 'READY'} />
                </div>
                <dl>
                  <dt>Agreement</dt>
                  <dd>{friendly(agreement?.status ?? 'unknown')}</dd>
                  <dt>Current odometer</dt>
                  <dd>{Number(vehicle?.odometer ?? 0).toLocaleString()} km</dd>
                  <dt>Documents and approval</dt>
                  <dd>{customerState?.ready ? 'Ready' : 'Incomplete'}</dd>
                  <dt>Registration / RWC</dt>
                  <dd>
                    {friendly(vehicleState?.registration_status ?? 'missing')} /{' '}
                    {friendly(vehicleState?.rwc_status ?? 'missing')}
                  </dd>
                  <dt>Maintenance</dt>
                  <dd>
                    {friendly(
                      vehicleState?.maintenance_status ?? 'not configured',
                    )}
                  </dd>
                  <dt>Visible issues</dt>
                  <dd>
                    {openIssues.length
                      ? openIssues
                          .map(
                            (x) =>
                              `${friendly(x.severity)} ${friendly(x.category)}`,
                          )
                          .join('; ')
                      : 'No open issues'}
                  </dd>
                </dl>
                {blockers.length > 0 && (
                  <div className="callout">
                    <strong>Cannot hand over yet</strong>
                    <ul>
                      {[...new Set(blockers)].map((b) => (
                        <li key={b}>{b}</li>
                      ))}
                    </ul>
                  </div>
                )}
                {i.staff_notes && (
                  <p>
                    <strong>Staff notes:</strong> {i.staff_notes}
                  </p>
                )}
                <form action={completePickup} className="form-card">
                  <input type="hidden" name="checklistId" value={i.id} />
                  <label>
                    Actual handover time
                    <input name="actualAt" type="datetime-local" required />
                  </label>
                  <label>
                    Handover odometer
                    <input
                      name="odometer"
                      type="number"
                      min={Number(vehicle?.odometer ?? 0)}
                      required
                    />
                  </label>
                  <label className="checkbox-row">
                    <input type="checkbox" name="handoverConfirmed" required />{' '}
                    I confirm the keys and vehicle were handed to the customer
                  </label>
                  <button disabled={blockers.length > 0}>
                    Complete handover and start custody
                  </button>
                </form>
              </article>
            );
          })}
        </div>
        {items?.length === 0 && (
          <p className="empty-state">No pickups are scheduled.</p>
        )}
      </section>
    </main>
  );
}
