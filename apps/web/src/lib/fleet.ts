import 'server-only';

import { requireStaff } from '@/lib/auth';

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

export type FleetOperation = { id:string; registration:string; make:string; model:string; year:number; odometer:number; operational_status:string; current_customer:string|null; agreement_id:string|null; agreement_status:string|null; next_pickup_at:string|null; next_return_at:string|null; open_issue_count:number; maintenance_status:string|null; ready_for_allocation:boolean };

export async function getFleet(): Promise<FleetVehicle[]> {
  const { supabase } = await requireStaff();
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

export async function getFleetOperations(): Promise<FleetOperation[]> {
  const { supabase } = await requireStaff();
  const { data, error } = await supabase.from('fleet_operations').select('*').order('registration');
  if (error) throw new Error(`Unable to load fleet operations: ${error.message}`);
  return (data ?? []) as FleetOperation[];
}

export async function getCustomers() {
  const { supabase } = await requireStaff();
  const { data, error } = await supabase.from('customer_operational_summary').select('*').order('full_name');
  if (error) throw new Error(`Unable to load customers: ${error.message}`);
  return (data ?? []).map(row=>({...row,id:row.customer_id}));
}

export async function getAssignmentHistory() {
  const { supabase } = await requireStaff();
  const { data, error } = await supabase
    .from('vehicle_assignments')
    .select(
      'id, assigned_at, returned_at, pickup_odometer, return_odometer, assignment_status, customers(full_name), vehicles(registration)',
    )
    .order('assigned_at', { ascending: false });
  if (error) throw new Error(`Unable to load assignments: ${error.message}`);
  return data ?? [];
}
