import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';
import { reviewPortalDocument, uploadSignedAgreement, viewDocument } from '@/lib/document-actions';

export default async function DocumentReview({searchParams}:{searchParams:Promise<{error?:string}>}) {
  const {supabase}=await requireStaff();
  const [{data},{data:agreements}]=await Promise.all([
    supabase.from('document_versions').select('id,document_type,uploaded_at,expiry_date,customer_id,customers:customer_id(full_name)').eq('status','PENDING_REVIEW').order('uploaded_at'),
    supabase.from('agreements').select('id,customer_id,status,customers(full_name)').in('status',['ACTIVE','PENDING_SIGNATURE']).order('created_at',{ascending:false}),
  ]);
  const {error}=await searchParams;
  return <main><StaffNav/><p className="eyebrow">Secure exchange</p><h1>Pending documents</h1>{error&&<p className="error">{error}</p>}
    <section><h2>Make a signed agreement available</h2><p>Upload only an already-signed PDF. This is not an electronic signing workflow.</p><form action={uploadSignedAgreement} className="form-grid"><label>Agreement<select name="agreementId" required>{agreements?.map(a=><option key={a.id} value={a.id}>{a.customers?.[0]?.full_name} · {a.id.slice(0,8)} · {a.status}</option>)}</select></label><label>Customer<select name="customerId" required>{agreements?.map(a=><option key={a.id} value={a.customer_id}>{a.customers?.[0]?.full_name}</option>)}</select></label><label>Type<select name="documentType"><option>SIGNED_RENTAL_AGREEMENT</option><option>RENT_TO_OWN_AGREEMENT</option></select></label><label>Signed PDF<input type="file" name="file" accept="application/pdf" required/></label><button>Make available</button></form></section>
    <div className="table-wrap"><table><thead><tr><th>Uploaded</th><th>Customer</th><th>Type</th><th>Expiry</th><th>Actions</th></tr></thead><tbody>{data?.map(d=><tr key={d.id}><td>{new Date(d.uploaded_at).toLocaleString('en-AU')}</td><td>{d.customers?.[0]?.full_name}</td><td>{d.document_type.replaceAll('_',' ')}</td><td>{d.expiry_date??'—'}</td><td><form action={viewDocument}><input type="hidden" name="documentId" value={d.id}/><input type="hidden" name="returnPath" value={`/customers/${d.customer_id}`}/><button>Preview</button></form><form action={reviewPortalDocument} className="inline-form"><input type="hidden" name="documentId" value={d.id}/><select name="decision"><option>VERIFIED</option><option>REJECTED</option><option value="REPLACED">REQUEST REPLACEMENT</option></select><input name="reason" maxLength={500} placeholder="Customer-safe reason"/><button>Save</button></form></td></tr>)}</tbody></table></div>
  </main>;
}
