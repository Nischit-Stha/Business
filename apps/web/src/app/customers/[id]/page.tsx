import { notFound } from 'next/navigation';
import { CustomerForm } from '@/components/management-forms';
import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';
import { changeCustomerStatus } from '@/lib/management-actions';
export default async function CustomerDetail({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) { const { id } = await params; const { supabase } = await requireStaff(); const { data } = await supabase.from('customers').select('*').eq('id', id).maybeSingle(); if (!data) notFound(); const { error } = await searchParams; return <main><StaffNav/><p className="eyebrow">Customer detail</p><h1>{data.full_name}</h1>{error && <p className="error">{error}</p>}<p>Status: <strong>{data.status}</strong></p><form action={changeCustomerStatus} className="inline-form"><input type="hidden" name="id" value={id}/><select name="status" defaultValue={data.status}><option>ACTIVE</option><option>INACTIVE</option><option>BLOCKED</option></select><button>Change status</button></form><h2>Edit details</h2><CustomerForm customer={data}/></main>; }
