import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';
import { completeReturn, scheduleReturn } from '@/lib/operations-actions';
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { supabase } = await requireStaff();
  const { error } = await searchParams;
  const [
    { data: assignments },
    { data: items },
    { data: details },
    { data: issues },
  ] = await Promise.all([
    supabase
      .from('vehicle_assignments')
      .select('id,vehicle_id,customers(full_name),vehicles(registration)')
      .eq('assignment_status', 'ACTIVE'),
    supabase
      .from('return_checklists')
      .select(
        '*,vehicle_assignments(vehicle_id,customers(full_name),vehicles(registration,odometer))',
      )
      .not('status', 'in', '(COMPLETED,CANCELLED)')
      .order('scheduled_at'),
    supabase
      .from('vehicle_operational_detail')
      .select('vehicle_id,readiness_blockers,maintenance_status'),
    supabase
      .from('vehicle_issues')
      .select('vehicle_id,severity,category')
      .not('status', 'in', '(RESOLVED,CANCELLED)'),
  ]);
  return (
    <main>
      <StaffNav />
      <p className="eyebrow">End physical custody</p>
      <h1>Vehicle returns</h1>
      <p className="lede">
        The system determines the safe resulting vehicle state. A car is
        released as available only when no agreement, issue, maintenance, or
        compliance blocker remains.
      </p>
      {error && (
        <p className="error" role="alert">
          <strong>Return was not completed.</strong> {error}
        </p>
      )}
      <section className="dashboard-section">
        <h2>Schedule a return</h2>
        <form action={scheduleReturn} className="form-card">
          <label>
            Vehicle and customer
            <select name="assignmentId" required>
              <option value="">Select active custody</option>
              {assignments?.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.vehicles?.[0]?.registration} —{' '}
                  {a.customers?.[0]?.full_name}
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
          <button>Schedule return</button>
        </form>
      </section>
      <section className="dashboard-section">
        <h2>Planned returns</h2>
        <div className="workflow-grid">
          {items?.map((i) => {
            const assignment = i.vehicle_assignments?.[0],
              vehicle = assignment?.vehicles?.[0],
              detail = details?.find(
                (r) => r.vehicle_id === assignment?.vehicle_id,
              ),
              openIssues =
                issues?.filter(
                  (x) => x.vehicle_id === assignment?.vehicle_id,
                ) ?? [];
            return (
              <form
                key={i.id}
                action={completeReturn}
                className="section-card form-card"
              >
                <input type="hidden" name="checklistId" value={i.id} />
                <h3>
                  {vehicle?.registration} ·{' '}
                  {assignment?.customers?.[0]?.full_name}
                </h3>
                <p>
                  <strong>Scheduled:</strong>{' '}
                  {i.scheduled_at
                    ? new Date(i.scheduled_at).toLocaleString('en-AU')
                    : 'Not scheduled'}
                </p>
                <p>
                  <strong>Visible issues:</strong>{' '}
                  {openIssues.length
                    ? openIssues
                        .map(
                          (x) =>
                            `${x.severity.toLowerCase()} ${x.category.replaceAll('_', ' ').toLowerCase()}`,
                        )
                        .join('; ')
                    : 'No open issues'}
                </p>
              {(detail?.readiness_blockers?.length ?? 0) > 0 && (
                <p className="callout">
                  <strong>Existing blockers:</strong>{' '}
                  {detail?.readiness_blockers?.join('; ')}
                  </p>
                )}
                {i.staff_notes && (
                  <p>
                    <strong>Staff notes:</strong> {i.staff_notes}
                  </p>
                )}
                <label>
                  Return odometer
                  <input
                    name="odometer"
                    type="number"
                    min={Number(vehicle?.odometer ?? 0)}
                    required
                  />
                </label>
                <label>
                  Condition at return
                  <select name="condition">
                    <option value="GOOD">Good — no new concern seen</option>
                    <option value="DAMAGE_NOTED">
                      Damage noted — keep off road
                    </option>
                    <option value="UNSAFE">Unsafe — keep off road</option>
                  </select>
                </label>
                <label className="checkbox-row">
                  <input type="checkbox" name="openIssue" /> Block vehicle for
                  issue follow-up
                </label>
                <p className="form-hint">
                  After completion the vehicle goes to Workshop when maintenance
                  is active, Off road when any blocker remains, or Available
                  only when fully clear.
                </p>
                <button>Complete return and end custody</button>
              </form>
            );
          })}
        </div>
        {items?.length === 0 && (
          <p className="empty-state">No returns are scheduled.</p>
        )}
      </section>
    </main>
  );
}
