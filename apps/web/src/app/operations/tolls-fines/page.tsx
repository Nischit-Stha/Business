import Link from 'next/link';
import {StaffNav} from '@/components/staff-nav';
import {TollFineCsvImport} from '@/components/toll-fine-csv-import';
import {requireStaff} from '@/lib/auth';
import {createNotice} from '@/lib/collections-actions';

const views=[['Needs Review',['NEEDS_REVIEW']],['Matched',['MATCHED','CONFIRMED']],['Transfer Pending',['TRANSFER_PENDING']],['Transferred',['TRANSFERRED']],['Disputed',['DISPUTED']]] as const;
export default async function Page({searchParams}:{searchParams:Promise<{error?:string;batch?:string}>}){
 const {error,batch}=await searchParams;const {supabase}=await requireStaff();
 await supabase.rpc('refresh_toll_fine_owner_attention',{});
 const [{data:notices},{data:vehicles},{data:importBatch},{data:rejections}]=await Promise.all([
  supabase.from('toll_fine_notices').select('*,vehicles(registration)').order('event_at',{ascending:false}),
  supabase.from('vehicles').select('id,registration').order('registration'),
  batch?supabase.from('toll_fine_import_batches').select('*').eq('id',batch).maybeSingle():Promise.resolve({data:null}),
  batch?supabase.from('toll_fine_import_rows').select('row_number,status,rejection_reason,raw_data').eq('batch_id',batch).neq('status','ACCEPTED').order('row_number'):Promise.resolve({data:null})
 ]);
 return <main><StaffNav/><p className="eyebrow">Operations</p><h1>Tolls &amp; Fines Automation</h1>{error&&<p className="error">{error}</p>}
 <p className="lede">Provider-neutral internal matching only. No liability is transferred automatically and no external provider is connected.</p>
 {importBatch&&<section><h2>Import report</h2><p>{importBatch.accepted_count} accepted · {importBatch.rejected_count} rejected/duplicate · checksum protected</p>{rejections?.length?<div className="table-wrap"><table><thead><tr><th>Row</th><th>Status</th><th>Reason</th><th>Registration</th></tr></thead><tbody>{rejections.map(r=><tr key={r.row_number}><td>{r.row_number}</td><td>{r.status}</td><td>{r.rejection_reason}</td><td>{String(r.raw_data?.registration??'—')}</td></tr>)}</tbody></table></div>:<p className="empty">No rejected rows.</p>}</section>}
 <section><h2>Synthetic CSV import</h2><TollFineCsvImport/></section>
 <section><h2>Manual entry</h2><form action={createNotice} className="form-grid"><label>Type<select name="noticeType">{['TOLL','PARKING_FINE','SPEEDING_FINE','OTHER_INFRINGEMENT'].map(x=><option key={x}>{x}</option>)}</select></label><label>External reference<input name="externalReference" maxLength={120}/></label><label>Vehicle<select name="vehicleId" required>{vehicles?.map(v=><option key={v.id} value={v.id}>{v.registration}</option>)}</select></label><label>Registration<input name="registrationSnapshot" required maxLength={20}/></label><label>Event date/time<input name="occurredAt" type="datetime-local" required/></label><input name="issuedAt" type="hidden"/><label>Amount<input name="amount" type="number" min="0" step=".01" required/></label><label>Authority/provider<input name="authorityProvider" maxLength={160}/></label><label className="wide">Notes<textarea name="notes" maxLength={2000}/></label><button>Create and match</button></form></section>
 {views.map(([title,statuses])=>{const rows=notices?.filter(n=>statuses.includes(n.status as never))??[];return <section key={title}><h2>{title}</h2><div className="table-wrap"><table><thead><tr><th>Event</th><th>Type</th><th>Reference</th><th>Vehicle</th><th>Amount</th><th>Confidence</th><th>Status</th></tr></thead><tbody>{rows.map(n=><tr key={n.id}><td><Link href={`/operations/tolls-fines/${n.id}`}>{n.event_at?new Date(n.event_at).toLocaleString('en-AU'):'Missing'}</Link></td><td>{n.type}</td><td>{n.external_reference??'—'}</td><td>{n.registration}</td><td>${Number(n.amount).toFixed(2)}</td><td>{n.match_confidence}</td><td>{n.status}</td></tr>)}</tbody></table></div>{rows.length===0&&<p className="empty">None.</p>}</section>})}</main>;
}
