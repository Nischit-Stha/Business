'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';
import { customerInput, vehicleInput } from '@/lib/validation';

function fail(path: string, message: string): never { redirect(`${path}?error=${encodeURIComponent(message)}`); }

export async function saveCustomer(form: FormData) {
  const id = String(form.get('id') ?? '');
  const { input, errors } = customerInput(form);
  const path = id ? `/customers/${id}` : '/customers/new';
  const firstError = Object.values(errors)[0];
  if (firstError) fail(path, firstError);
  const { supabase } = await requireStaff();
  const fn = id ? 'update_customer' : 'create_customer';
  const { data, error } = await supabase.rpc(fn, {
    ...(id ? { p_id: id } : {}), p_full_name: input.fullName, p_phone: input.phone,
    p_email: input.email, p_licence_number: input.licenceNumber,
    p_licence_expiry: input.licenceExpiry, p_address: input.address,
  });
  if (error) fail(path, error.code === '23505' ? 'That licence number already exists.' : error.message);
  const customer = Array.isArray(data) ? data[0] : data;
  revalidatePath('/customers');
  redirect(`/customers/${id || customer.id}`);
}

export async function changeCustomerStatus(form: FormData) {
  const id = String(form.get('id') ?? '');
  const status = String(form.get('status') ?? '');
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('change_customer_status', { p_id: id, p_status: status });
  if (error) fail(`/customers/${id}`, error.message);
  revalidatePath('/customers'); revalidatePath(`/customers/${id}`); redirect(`/customers/${id}`);
}

export async function saveVehicle(form: FormData) {
  const id = String(form.get('id') ?? '');
  const { input, errors } = vehicleInput(form);
  const path = id ? `/fleet/${id}` : '/fleet/new';
  const firstError = Object.values(errors)[0];
  if (firstError) fail(path, firstError);
  const { supabase } = await requireStaff();
  const fn = id ? 'update_vehicle' : 'create_vehicle';
  const { data, error } = await supabase.rpc(fn, {
    ...(id ? { p_id: id } : {}), p_registration: input.registration, p_vin: input.vin || null,
    p_make: input.make, p_model: input.model, p_year: input.year, p_odometer: input.odometer,
    p_weekly_rate: input.weeklyRate, p_operational_status: input.operationalStatus,
  });
  if (error) fail(path, error.code === '23505' ? 'That registration or VIN already exists.' : error.message);
  const vehicle = Array.isArray(data) ? data[0] : data;
  revalidatePath('/fleet'); redirect(`/fleet/${id || vehicle.id}`);
}
