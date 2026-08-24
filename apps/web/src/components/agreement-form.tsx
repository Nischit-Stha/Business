import { createAgreement } from '@/lib/agreement-actions';

type OptionData = { customers: Array<{ id: string; full_name: string }>; assignments: Array<{ customer_id: string; vehicle_id: string; vehicles: Array<{ registration: string; make: string; model: string }> }> };

export function AgreementForm({ options }: { options: OptionData }) {
  return <form action={createAgreement} className="form-grid">
    <label>Customer<select name="customerId" required><option value="">Select customer</option>{options.customers.map((c) => <option key={c.id} value={c.id}>{c.full_name}</option>)}</select></label>
    <label>Assigned vehicle<select name="vehicleId" required><option value="">Select vehicle</option>{options.assignments.map((a) => <option key={a.vehicle_id} value={a.vehicle_id}>{a.vehicles[0]?.registration} — {a.vehicles[0]?.make} {a.vehicles[0]?.model}</option>)}</select><small>Activation verifies the selected customer and vehicle have a matching active assignment.</small></label>
    <label>Type<select name="agreementType" required><option>WEEKLY_RENTAL</option><option>RENT_TO_OWN</option><option>SHORT_TERM</option></select></label>
    <label>Weekly amount<input name="weeklyAmount" type="number" min="0.01" step="0.01" required /></label>
    <label>Start date<input name="startDate" type="date" required /></label>
    <label>First due date<input name="firstDueDate" type="date" required /></label>
    <label>End date (optional)<input name="endDate" type="date" /></label>
    <label>Deposit amount<input name="depositAmount" type="number" min="0" step="0.01" defaultValue="0" required /></label>
    <label>RTO agreed total<input name="agreedTotalAmount" type="number" min="0.01" step="0.01" /></label>
    <label>RTO payment count<input name="agreedPaymentCount" type="number" min="1" step="1" /></label>
    <label>External provider<input name="externalContractProvider" maxLength={80} placeholder="Future provider, e.g. Renta" /></label>
    <label>External contract ID<input name="externalContractId" maxLength={160} /></label>
    <button type="submit">Create draft agreement</button>
  </form>;
}
