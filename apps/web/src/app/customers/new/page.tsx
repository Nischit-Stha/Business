import { CustomerForm } from '@/components/management-forms';
import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';
export default async function NewCustomerPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) { await requireStaff(); const { error } = await searchParams; return <main><StaffNav/><p className="eyebrow">Customers</p><h1>New customer</h1>{error && <p className="error">{error}</p>}<CustomerForm/></main>; }
