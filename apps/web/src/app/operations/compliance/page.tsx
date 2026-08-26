import { StaffNav } from '@/components/staff-nav';
import { StatusBadge } from '@/components/ui';
import { requireStaff } from '@/lib/auth';
import { setCompliance } from '@/lib/operations-actions';
const label: Record<string, string> = {
  VALID: 'Valid',
  EXPIRING_SOON: 'Expiring soon',
  EXPIRED: 'Expired — blocks pickup',
  MISSING: 'Missing — blocks pickup',
};
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; q?: string }>;
}) {
  const { supabase } = await requireStaff();
  const { error, q } = await searchParams;
  const [{ data: vehicles }, { data: records }, { data: exposure }] =
    await Promise.all([
      supabase
        .from('vehicles')
        .select('id,registration,make,model,operational_status')
        .order('registration'),
      supabase.from('vehicle_compliance').select('*'),
      supabase.from('vehicle_compliance_exposure').select('*'),
    ]);
  const filtered = (vehicles ?? []).filter(
    (v) =>
      !q ||
      `${v.registration} ${v.make} ${v.model}`
        .toLowerCase()
        .includes(q.toLowerCase()),
  );
  const groups = [
    ['Expired or missing', ['EXPIRED', 'MISSING']],
    ['Warning — expiring soon', ['EXPIRING_SOON']],
    ['Valid', ['VALID']],
  ] as const;
  return (
    <main>
      <StaffNav />
      <p className="eyebrow">Registration and roadworthy readiness</p>
      <h1>Vehicle compliance</h1>
      <p className="lede">
        Expired or missing records block pickup. Review the evidence before
        updating a record.
      </p>
      {error && (
        <p className="error" role="alert">
          <strong>Compliance was not updated.</strong> {error}
        </p>
      )}
      <form className="inline-form">
        <label>
          Find vehicle
          <input
            name="q"
            defaultValue={q}
            placeholder="Registration, make or model"
          />
        </label>
        <button>Search</button>
      </form>
      {groups.map(([title, statuses]) => {
        const rows = filtered.filter((v) => {
          const states = exposure
            ?.filter((e) => e.vehicle_id === v.id)
            .map((e) => e.exposure) ?? ['MISSING'];
          return states.some((s) => statuses.includes(s as never));
        });
        return (
          <section className="dashboard-section" key={title}>
            <h2>
              {title} ({rows.length})
            </h2>
            <div className="workflow-grid">
              {rows.map((v) => {
                const current =
                  records?.filter((r) => r.vehicle_id === v.id) ?? [];
                return (
                  <article className="section-card" key={v.id}>
                    <div className="section-card-header">
                      <div>
                        <h3>{v.registration}</h3>
                        <p>
                          {v.make} {v.model} ·{' '}
                          {v.operational_status
                            .replaceAll('_', ' ')
                            .toLowerCase()}
                        </p>
                      </div>
                    </div>
                    <div className="compliance-records">
                      {['REGISTRATION', 'RWC'].map((type) => {
                        const r = current.find(
                            (x) => x.compliance_type === type,
                          ),
                          e = exposure?.find(
                            (x) =>
                              x.vehicle_id === v.id &&
                              x.compliance_type === type,
                          ),
                          state = e?.exposure ?? 'MISSING';
                        return (
                          <div key={type}>
                            <strong>
                              {type === 'REGISTRATION'
                                ? 'Registration'
                                : 'Roadworthy certificate'}
                            </strong>
                            <StatusBadge status={state} />
                            <span>
                              {label[state] ?? state}
                              {e?.expires_at
                                ? ` · expires ${new Date(`${e.expires_at}T00:00:00`).toLocaleDateString('en-AU')}`
                                : ' · no expiry recorded'}
                            </span>
                            {r?.issued_at && (
                              <small>
                                Issued{' '}
                                {new Date(
                                  `${r.issued_at}T00:00:00`,
                                ).toLocaleDateString('en-AU')}
                              </small>
                            )}
                          </div>
                        );
                      })}
                    </div>
                    <details>
                      <summary>Update compliance record</summary>
                      <form action={setCompliance} className="form-card">
                        <input type="hidden" name="vehicleId" value={v.id} />
                        <label>
                          Record type
                          <select name="type">
                            <option value="REGISTRATION">Registration</option>
                            <option value="RWC">Roadworthy certificate</option>
                          </select>
                        </label>
                        <label>
                          Verified status
                          <select name="status">
                            <option value="VALID">Valid</option>
                            <option value="EXPIRING_SOON">Expiring soon</option>
                            <option value="EXPIRED">Expired</option>
                            <option value="MISSING">Missing</option>
                          </select>
                        </label>
                        <label>
                          Issued date
                          <input name="issuedAt" type="date" />
                        </label>
                        <label>
                          Expiry date
                          <input name="expiresAt" type="date" required />
                        </label>
                        <button>Save verified record</button>
                      </form>
                    </details>
                  </article>
                );
              })}
            </div>
            {rows.length === 0 && (
              <p className="empty-state">No vehicles in this group.</p>
            )}
          </section>
        );
      })}
    </main>
  );
}
