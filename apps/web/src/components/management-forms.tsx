import { saveCustomer, saveVehicle } from '@/lib/management-actions';

export function CustomerForm({ customer }: { customer?: Record<string, string | null> }) {
  return <form action={saveCustomer} className="form-grid">
    {customer?.id && <input type="hidden" name="id" value={customer.id} />}
    <label>Full name<input name="fullName" required maxLength={160} defaultValue={customer?.full_name ?? ''} /></label>
    <label>Phone<input name="phone" type="tel" required defaultValue={customer?.phone ?? ''} /></label>
    <label>Email<input name="email" type="email" required defaultValue={customer?.email ?? ''} /></label>
    <label>Licence number<input name="licenceNumber" required maxLength={80} defaultValue={customer?.licence_number ?? ''} /></label>
    <label>Licence expiry<input name="licenceExpiry" type="date" required defaultValue={customer?.licence_expiry ?? ''} /></label>
    <label className="wide">Address<textarea name="address" required maxLength={500} defaultValue={customer?.address ?? ''} /></label>
    <button type="submit">{customer ? 'Save customer' : 'Create customer'}</button>
  </form>;
}

export function VehicleForm({ vehicle }: { vehicle?: Record<string, string | number | null> }) {
  const current = String(vehicle?.operational_status ?? 'AVAILABLE');
  const assignmentControlled = ['ASSIGNED', 'PICKUP_PENDING', 'RETURN_PENDING'].includes(current);
  return <form action={saveVehicle} className="form-grid">
    {vehicle?.id && <input type="hidden" name="id" value={String(vehicle.id)} />}
    <label>Registration<input name="registration" required maxLength={20} defaultValue={String(vehicle?.registration ?? '')} /></label>
    <label>VIN<input name="vin" maxLength={40} defaultValue={String(vehicle?.vin ?? '')} /></label>
    <label>Make<input name="make" required maxLength={80} defaultValue={String(vehicle?.make ?? '')} /></label>
    <label>Model<input name="model" required maxLength={80} defaultValue={String(vehicle?.model ?? '')} /></label>
    <label>Year<input name="year" type="number" required min="1900" max={new Date().getFullYear() + 1} defaultValue={String(vehicle?.year ?? '')} /></label>
    <label>Odometer<input name="odometer" type="number" required min={Number(vehicle?.odometer ?? 0)} defaultValue={String(vehicle?.odometer ?? '0')} /></label>
    <label>Weekly rate<input name="weeklyRate" type="number" required min="0" step="0.01" defaultValue={String(vehicle?.weekly_rate ?? '')} /></label>
    <label>Operational status<select name="operationalStatus" defaultValue={current} disabled={assignmentControlled}>{assignmentControlled && <option value={current}>{current.replaceAll('_', ' ')}</option>}<option value="AVAILABLE">AVAILABLE</option><option value="WORKSHOP">WORKSHOP</option><option value="OFF_ROAD">OFF ROAD</option></select>{assignmentControlled && <input type="hidden" name="operationalStatus" value={current} />}</label>
    <button type="submit">{vehicle ? 'Save vehicle' : 'Create vehicle'}</button>
  </form>;
}
