'use server';

import { createHash } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';

const value = (form: FormData, key: string) => String(form.get(key) ?? '').trim();
const fail = (path: string, message: string): never => redirect(`${path}?error=${encodeURIComponent(message)}`);

function parseCsv(text: string) {
  const lines: string[][] = [];
  let row: string[] = [], cell = '', quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (char === '"' && quoted && text[i + 1] === '"') { cell += '"'; i += 1; }
    else if (char === '"') quoted = !quoted;
    else if (char === ',' && !quoted) { row.push(cell); cell = ''; }
    else if ((char === '\n' || char === '\r') && !quoted) {
      if (char === '\r' && text[i + 1] === '\n') i += 1;
      row.push(cell); if (row.some((entry) => entry.trim())) lines.push(row); row = []; cell = '';
    } else cell += char;
  }
  row.push(cell); if (row.some((entry) => entry.trim())) lines.push(row);
  if (quoted || lines.length < 2) throw new Error('CSV must contain a header and at least one row.');
  const headers = lines[0].map((header) => header.trim());
  const required = ['external_transaction_id', 'transaction_date', 'received_at', 'amount', 'description', 'payer_name_raw', 'reference_raw'];
  if (headers.join('|') !== required.join('|')) throw new Error(`CSV columns must be exactly: ${required.join(', ')}`);
  if (lines.length > 501) throw new Error('Synthetic imports are limited to 500 rows.');
  return lines.slice(1).map((fields) => Object.fromEntries(headers.map((header, index) => [header, (fields[index] ?? '').trim()])));
}

export async function importSyntheticCsv(form: FormData) {
  const path = '/reconciliation/import';
  const { supabase } = await requireStaff();
  const file = form.get('file');
  if (!(file instanceof File) || !file.name.toLowerCase().endsWith('.csv')) fail(path, 'Choose a synthetic CSV file.');
  const upload = file as File;
  if (upload.size > 512_000) fail(path, 'CSV must be 500 KB or smaller.');
  const bytes = Buffer.from(await upload.arrayBuffer());
  const checksum = createHash('sha256').update(bytes).digest('hex');
  let rows: Record<string, string>[] = [];
  try { rows = parseCsv(bytes.toString('utf8')); } catch (error) {
    await supabase.rpc('record_synthetic_bank_import_failure', { p_source_identifier: upload.name, p_checksum: checksum, p_row_count: 0 });
    fail(path, error instanceof Error ? error.message : 'Invalid CSV.');
  }
  const { data, error } = await supabase.rpc('import_synthetic_bank_csv', {
    p_source_identifier: upload.name,
    p_checksum: checksum,
    p_rows: rows,
  });
  if (error) fail(path, error.message);
  revalidatePath('/reconciliation'); revalidatePath(path);
  redirect(`${path}?batch=${data.id}`);
}

export async function reconcileBankTransaction(form: FormData) {
  const id = value(form, 'transactionId'); const path = `/reconciliation/${id}`;
  const { supabase } = await requireStaff();
  const agreementIds = form.getAll('agreementId').map(String).filter(Boolean);
  const amounts = form.getAll('allocationAmount').map(Number);
  const allocations = agreementIds.map((agreement_id, index) => ({ agreement_id, amount: amounts[index] }));
  const { error } = await supabase.rpc('reconcile_bank_transaction', { p_transaction_id: id, p_allocations: allocations, p_reason: value(form, 'reason'), p_match_run_id: value(form, 'matchRunId') || null });
  if (error) fail(path, error.message);
  revalidatePath('/reconciliation'); revalidatePath(path); revalidatePath('/payments'); revalidatePath('/collections'); redirect(path);
}

export async function autoAllocateBankTransaction(form: FormData) {
  const id=value(form,'transactionId'); const path=`/reconciliation/${id}`; const {supabase}=await requireStaff();
  const {error}=await supabase.rpc('auto_allocate_bank_transaction',{p_transaction_id:id}); if(error)fail(path,error.message);
  revalidatePath('/reconciliation');revalidatePath(path);redirect(path);
}

export async function ignoreBankTransaction(form: FormData) {
  const id=value(form,'transactionId');const path=`/reconciliation/${id}`;const {supabase}=await requireStaff();
  const {error}=await supabase.rpc('ignore_bank_transaction',{p_transaction_id:id,p_reason:value(form,'reason')});if(error)fail(path,error.message);
  revalidatePath('/reconciliation');revalidatePath(path);redirect(path);
}

export async function reverseBankReconciliation(form: FormData) {
  const id=value(form,'transactionId');const path=`/reconciliation/${id}`;const {supabase}=await requireStaff();
  const {error}=await supabase.rpc('reverse_bank_reconciliation',{p_transaction_id:id,p_reason:value(form,'reason')});if(error)fail(path,error.message);
  revalidatePath('/reconciliation');revalidatePath(path);revalidatePath('/payments');revalidatePath('/collections');redirect(path);
}
