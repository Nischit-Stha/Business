import { getCustomers } from '@/lib/fleet';
import { StaffNav } from '@/components/staff-nav';
import { CustomerList } from '@/components/customer-list';
import { ActionButton, PageHeader } from '@/components/ui';

export const dynamic = 'force-dynamic';

export default async function CustomersPage() {
  const customers = await getCustomers();
  return <main id="main-content"><StaffNav/><PageHeader eyebrow="Customer operations" title="Customers" description="Customer readiness and active rental relationships, without unnecessary personal details." actions={<ActionButton href="/customers/new">Add customer</ActionButton>}/><CustomerList customers={customers} today={new Date().toISOString().slice(0,10)}/></main>;
}
