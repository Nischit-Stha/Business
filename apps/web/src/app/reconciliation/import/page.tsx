import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { SyntheticCsvImport } from '@/components/synthetic-csv-import';
import { requireStaff } from '@/lib/auth';

export default async function Page({searchParams}:{searchParams:Promise<{error?:string,batch?:string}>}) {
  const {error,batch}=await searchParams; const {supabase}=await requireStaff();
  const {data:batches}=await supabase.from('import_batches').select('*').order('imported_at',{ascending:false}).limit(20);
  const selected=batch?batches?.find(item=>item.id===batch):undefined;
  return <main><StaffNav/><p className="eyebrow">Local and staging test tool</p><h1>Import synthetic CSV</h1><p className="lede">This page accepts the documented synthetic format only. It has no bank connection and must not be used for real banking files in production.</p>{error&&<p className="error">{error}</p>}{selected&&<p>Batch result: {selected.status} — {JSON.stringify(selected.result)}</p>}<SyntheticCsvImport/><h2>Recent batches</h2><div className="table-wrap"><table><thead><tr><th>File</th><th>Status</th><th>Rows</th><th>Result</th><th>Imported</th></tr></thead><tbody>{batches?.map(item=><tr key={item.id}><td>{item.source_identifier}</td><td>{item.status}</td><td>{item.row_count}</td><td>{JSON.stringify(item.result)}</td><td>{new Date(item.imported_at).toLocaleString('en-AU')}</td></tr>)}</tbody></table></div><p><Link href="/reconciliation">Return to reconciliation</Link></p></main>;
}
