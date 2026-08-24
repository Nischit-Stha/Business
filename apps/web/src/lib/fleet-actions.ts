'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { requireStaff } from '@/lib/auth';

async function invokeWorkflow(functionName: string, parameters: Record<string, unknown>) {
  await requireStaff();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(functionName, parameters);
  if (error) throw new Error(error.message);
  revalidatePath('/fleet');
  revalidatePath('/assignments');
  return data;
}

export async function assignVehicleForm(form: FormData) {
  await assignVehicle({ customerId: String(form.get('customerId')), vehicleId: String(form.get('vehicleId')), pickupOdometer: Number(form.get('pickupOdometer')) });
}

export async function returnVehicleForm(form: FormData) {
  await returnVehicle({ assignmentId: String(form.get('assignmentId')), returnOdometer: Number(form.get('returnOdometer')) });
}

export async function swapVehicleForm(form: FormData) {
  const agreementId = String(form.get('agreementId'));
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('swap_active_agreement_vehicle', {
    p_agreement_id: agreementId,
    p_new_vehicle_id: String(form.get('newVehicleId')),
    p_old_return_odometer: Number(form.get('oldReturnOdometer')),
    p_new_pickup_odometer: Number(form.get('newPickupOdometer')),
  });
  if (error) {
    await supabase.rpc('report_vehicle_swap_failure', {
      p_agreement_id: agreementId, p_summary: error.message,
      p_metadata: { target_vehicle_id: String(form.get('newVehicleId')) },
    });
    redirect(`/swap?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/fleet'); revalidatePath('/assignments'); revalidatePath('/agreements'); revalidatePath('/owner');
  redirect(`/agreements/${agreementId}`);
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
