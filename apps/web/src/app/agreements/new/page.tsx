import { AgreementForm } from '@/components/agreement-form';
import { StaffNav } from '@/components/staff-nav';
import { getAgreementFormOptions } from '@/lib/agreements';

export default async function NewAgreementPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const options = await getAgreementFormOptions(); const { error } = await searchParams;
  return <main><StaffNav/><p className="eyebrow">Agreements</p><h1>New agreement</h1>{error && <p className="error">{error}</p>}<p className="lede">Creates a draft. Activation is a separate controlled step after signature and assignment checks.</p><AgreementForm options={options}/></main>;
}
