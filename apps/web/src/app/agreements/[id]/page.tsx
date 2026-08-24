import { notFound } from 'next/navigation';
import { StaffNav } from '@/components/staff-nav';
import { extendSchedule, recordPayment, reversePayment, transitionAgreement } from '@/lib/agreement-actions';
import { getAgreement } from '@/lib/agreements';

function money(value: unknown) { return `$${Number(value ?? 0).toFixed(2)}`; }
const transitions: Record<string,string[]> = { DRAFT:['PENDING_SIGNATURE','CANCELLED'], PENDING_SIGNATURE:['ACTIVE','CANCELLED'], ACTIVE:['SUSPENDED','COMPLETED','CANCELLED'], SUSPENDED:['ACTIVE','COMPLETED','CANCELLED'] };

export default async function AgreementDetail({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) {
  const { id } = await params; const result = await getAgreement(id); const { error } = await searchParams;
  if (!result.agreement) notFound(); const a = result.agreement; const summary = result.summary;
  return <main><StaffNav/><p className="eyebrow">Agreement detail</p><h1>{a.customers?.[0]?.full_name ?? 'Agreement'}</h1>{error && <p className="error">{error}</p>}
    <div className="summary-grid"><div><small>Vehicle</small><strong>{a.vehicles?.[0]?.registration} — {a.vehicles?.[0]?.make} {a.vehicles?.[0]?.model}</strong></div><div><small>Type</small><strong>{a.agreement_type.replaceAll('_',' ')}</strong></div><div><small>Weekly</small><strong>{money(a.weekly_amount)}</strong></div><div><small>Status</small><strong>{a.status}</strong></div><div><small>Overdue</small><strong>{money(summary?.overdue_amount)}</strong></div><div><small>Next payment</small><strong>{summary?.next_payment_date ?? '—'}</strong></div></div>
    {result.progress && <p>Rent-to-own progress: <strong>{result.progress.payments_completed}</strong> payments complete; <strong>{money(result.progress.scheduled_balance_remaining)}</strong> scheduled balance remaining.</p>}
    {(transitions[a.status] ?? []).length > 0 && <form action={transitionAgreement} className="inline-form"><input type="hidden" name="id" value={id}/><label>Lifecycle action<select name="status">{transitions[a.status].map((s) => <option key={s}>{s}</option>)}</select></label><button>Apply</button></form>}
    <h2>Record PayID payment</h2><form action={recordPayment} className="form-grid"><input type="hidden" name="agreementId" value={id}/><label>Amount<input name="amount" type="number" min="0.01" step="0.01" required/></label><label>Received at<input name="receivedAt" type="datetime-local" required/></label><label>Reference<input name="reference" maxLength={160}/></label><label>Notes<input name="notes" maxLength={500}/></label><button>Record verified payment</button></form>
    <h2>Schedule</h2><form action={extendSchedule} className="inline-form"><input type="hidden" name="id" value={id}/><label>Extend through<input name="throughDate" type="date" required/></label><button>Extend idempotently</button></form>
    <div className="table-wrap"><table><thead><tr><th>#</th><th>Due</th><th>Amount</th><th>Paid</th><th>Status</th></tr></thead><tbody>{result.schedule.map((s) => <tr key={s.id}><td>{s.sequence_number}</td><td>{s.due_date}</td><td>{money(s.amount_due)}</td><td>{money(s.amount_paid)}</td><td>{s.amount_paid >= s.amount_due ? 'PAID' : s.due_date < new Date().toISOString().slice(0,10) ? 'OVERDUE' : s.status}</td></tr>)}</tbody></table></div>
    <h2>Received payments</h2><div className="table-wrap"><table><thead><tr><th>Received</th><th>Type</th><th>Amount</th><th>Reference / notes</th><th>Unallocated</th><th>Correction</th></tr></thead><tbody>{result.payments.map((p) => <tr key={p.id}><td>{new Date(p.received_at).toLocaleString('en-AU')}</td><td>{p.transaction_type}</td><td>{money(p.amount)}</td><td>{p.reference ?? p.notes ?? '—'}</td><td>{money(p.unallocated_amount)}</td><td>{p.transaction_type === 'RECEIPT' && <form action={reversePayment} className="compact-form"><input type="hidden" name="agreementId" value={id}/><input type="hidden" name="paymentId" value={p.id}/><input name="reason" required placeholder="Reversal reason"/><button>Reverse</button></form>}</td></tr>)}</tbody></table></div>
  </main>;
}
