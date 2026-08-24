import 'server-only';

import { createSupabaseServerClient } from '@/lib/supabase/server';

export type FleetVehicle = {
  id: string;
  registration: string;
  make: string;
  model: string;
  year: number;
  odometer: number;
  operational_status: string;
  weekly_rate: number;
  vehicle_assignments: Array<{
    assignment_status: string;
    customers: Array<{ full_name: string }>;
  }>;
};

export async function getFleet(): Promise<FleetVehicle[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('vehicles')
    .select(
      'id, registration, make, model, year, odometer, operational_status, weekly_rate, vehicle_assignments!left(assignment_status, customers(full_name))',
    )
    .eq('vehicle_assignments.assignment_status', 'ACTIVE')
    .order('registration');

  if (error) throw new Error(`Unable to load fleet: ${error.message}`);
  return (data ?? []) as unknown as FleetVehicle[];
}

export async function getCustomers() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('customers')
    .select('id, full_name, phone, email, licence_expiry, status')
    .order('full_name');
  if (error) throw new Error(`Unable to load customers: ${error.message}`);
  return data ?? [];
}

export async function getAssignmentHistory() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('vehicle_assignments')
    .select(
      'id, assigned_at, returned_at, pickup_odometer, return_odometer, assignment_status, customers(full_name), vehicles(registration)',
    )
    .order('assigned_at', { ascending: false });
  if (error) throw new Error(`Unable to load assignments: ${error.message}`);
  return data ?? [];
}
