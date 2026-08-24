'use server';

import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';

async function invokeWorkflow(functionName: string, parameters: Record<string, unknown>) {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(functionName, parameters);
  if (error) throw new Error(error.message);
  revalidatePath('/fleet');
  revalidatePath('/assignments');
  return data;
}

export async function assignVehicle(input: {
  customerId: string;
  vehicleId: string;
  pickupOdometer: number;
  assignedAt?: string;
}) {
  return invokeWorkflow('assign_vehicle_to_customer', {
    p_customer_id: input.customerId,
    p_vehicle_id: input.vehicleId,
    p_pickup_odometer: input.pickupOdometer,
    ...(input.assignedAt ? { p_assigned_at: input.assignedAt } : {}),
  });
}

export async function returnVehicle(input: {
  assignmentId: string;
  returnOdometer: number;
  returnedAt?: string;
}) {
  return invokeWorkflow('return_vehicle', {
    p_assignment_id: input.assignmentId,
    p_return_odometer: input.returnOdometer,
    ...(input.returnedAt ? { p_returned_at: input.returnedAt } : {}),
  });
}

export async function swapVehicle(input: {
  assignmentId: string;
  newVehicleId: string;
  oldReturnOdometer: number;
  newPickupOdometer: number;
  swappedAt?: string;
}) {
  return invokeWorkflow('swap_vehicle', {
    p_assignment_id: input.assignmentId,
    p_new_vehicle_id: input.newVehicleId,
    p_old_return_odometer: input.oldReturnOdometer,
    p_new_pickup_odometer: input.newPickupOdometer,
    ...(input.swappedAt ? { p_swapped_at: input.swappedAt } : {}),
  });
}
