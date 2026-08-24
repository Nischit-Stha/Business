export type FieldErrors = Record<string, string>;

const text = (value: FormDataEntryValue | null) => String(value ?? '').trim();

export function customerInput(form: FormData) {
  const input = {
    fullName: text(form.get('fullName')),
    phone: text(form.get('phone')),
    email: text(form.get('email')).toLowerCase(),
    licenceNumber: text(form.get('licenceNumber')).toUpperCase(),
    licenceExpiry: text(form.get('licenceExpiry')),
    address: text(form.get('address')),
  };
  const errors: FieldErrors = {};
  if (!input.fullName || input.fullName.length > 160) errors.fullName = 'Enter a full name (maximum 160 characters).';
  if (!/^\+?[0-9 ()-]{8,20}$/.test(input.phone)) errors.phone = 'Enter a valid phone number.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email)) errors.email = 'Enter a valid email address.';
  if (!input.licenceNumber || input.licenceNumber.length > 80) errors.licenceNumber = 'Enter a licence number.';
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input.licenceExpiry)) errors.licenceExpiry = 'Enter a licence expiry date.';
  if (!input.address || input.address.length > 500) errors.address = 'Enter an address.';
  return { input, errors };
}

export function vehicleInput(form: FormData) {
  const input = {
    registration: text(form.get('registration')).toUpperCase(), vin: text(form.get('vin')).toUpperCase(),
    make: text(form.get('make')), model: text(form.get('model')), year: Number(text(form.get('year'))),
    odometer: Number(text(form.get('odometer'))), weeklyRate: Number(text(form.get('weeklyRate'))),
    operationalStatus: text(form.get('operationalStatus')) || 'AVAILABLE',
  };
  const errors: FieldErrors = {};
  if (!input.registration || input.registration.length > 20) errors.registration = 'Enter a registration.';
  if (input.vin.length > 40) errors.vin = 'VIN is too long.';
  if (!input.make || input.make.length > 80) errors.make = 'Enter a make.';
  if (!input.model || input.model.length > 80) errors.model = 'Enter a model.';
  if (!Number.isInteger(input.year) || input.year < 1900 || input.year > new Date().getFullYear() + 1) errors.year = 'Enter a valid year.';
  if (!Number.isInteger(input.odometer) || input.odometer < 0) errors.odometer = 'Enter a valid odometer.';
  if (!Number.isFinite(input.weeklyRate) || input.weeklyRate < 0) errors.weeklyRate = 'Enter a valid weekly rate.';
  if (!['AVAILABLE', 'WORKSHOP', 'OFF_ROAD'].includes(input.operationalStatus)) errors.operationalStatus = 'Choose a non-assignment status.';
  return { input, errors };
}
