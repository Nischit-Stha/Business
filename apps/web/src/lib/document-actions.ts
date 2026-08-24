'use server';

import { createHash, randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth';

const MAX_BYTES = 10 * 1024 * 1024;
const TYPES = {
  'application/pdf': { extension: 'pdf', matches: (b: Uint8Array) => Buffer.from(b.subarray(0, 5)).toString() === '%PDF-' },
  'image/jpeg': { extension: 'jpg', matches: (b: Uint8Array) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  'image/png': { extension: 'png', matches: (b: Uint8Array) => Buffer.from(b.subarray(0, 8)).equals(Buffer.from([137,80,78,71,13,10,26,10])) },
} as const;
type AllowedMime = keyof typeof TYPES;

function safeReturnPath(value: FormDataEntryValue | null) {
  const path = String(value ?? '');
  return /^\/(customers|fleet)\/[0-9a-f-]{36}$/.test(path) ? path : '/';
}
function fail(path: string, message: string): never { redirect(`${path}?error=${encodeURIComponent(message)}`); }
function cleanFilename(value: string) {
  const cleaned = value.normalize('NFKC').replace(/[\u0000-\u001f\u007f/\\]/g, '_').replace(/\s+/g, ' ').trim();
  return cleaned.slice(0, 255) || 'document';
}

export async function uploadDocument(form: FormData) {
  const path = safeReturnPath(form.get('returnPath'));
  const file = form.get('file');
  if (!(file instanceof File) || file.size === 0) fail(path, 'Choose a non-empty document');
  if (file.size > MAX_BYTES) fail(path, 'File size exceeds 10 MiB limit');
  const bytes = new Uint8Array(await file.arrayBuffer());
  const detected = (Object.entries(TYPES) as [AllowedMime, (typeof TYPES)[AllowedMime]][]).find(([, rule]) => rule.matches(bytes));
  if (!detected) fail(path, 'Only genuine PDF, JPEG, and PNG files are supported');
  const [mime, rule] = detected;
  const subjectId = String(form.get('subjectId'));
  const documentType = String(form.get('documentType'));
  const customer = ['DRIVER_LICENCE','PROOF_OF_ADDRESS'].includes(documentType);
  if (!/^[0-9a-f-]{36}$/.test(subjectId) || !['DRIVER_LICENCE','PROOF_OF_ADDRESS','REGISTRATION','RWC'].includes(documentType)) fail(path, 'Invalid document request');
  const bucket = customer ? 'customer-documents' : 'vehicle-compliance-documents';
  const objectPath = `${customer ? 'customers' : 'vehicles'}/${subjectId}/${documentType.toLowerCase()}/${randomUUID()}.${rule.extension}`;
  const checksum = createHash('sha256').update(bytes).digest('hex');
  const { supabase } = await requireStaff();
  const { error: uploadError } = await supabase.storage.from(bucket).upload(objectPath, bytes, { contentType: mime, upsert: false, cacheControl: 'private, max-age=0' });
  if (uploadError) fail(path, uploadError.message);
  const { error } = await supabase.rpc('register_document_upload', {
    p_subject_id: subjectId, p_document_type: documentType, p_bucket: bucket, p_object_path: objectPath,
    p_original_filename: cleanFilename(file.name), p_mime_type: mime, p_file_size: file.size,
    p_checksum_sha256: checksum, p_expiry_date: String(form.get('expiryDate') || '') || null,
  });
  if (error) { await supabase.storage.from(bucket).remove([objectPath]); fail(path, error.message); }
  revalidatePath(path);
}

export async function decideDocument(form: FormData) {
  const path = safeReturnPath(form.get('returnPath'));
  const { supabase } = await requireStaff();
  const { error } = await supabase.rpc('decide_document_version', { p_document_id:String(form.get('documentId')),p_decision:String(form.get('decision')),p_expiry_date:String(form.get('expiryDate')||'')||null,p_reason:String(form.get('reason')||'')||null });
  if (error) fail(path,error.message); revalidatePath(path);
}

export async function viewDocument(form: FormData) {
  const path = safeReturnPath(form.get('returnPath'));
  const { supabase } = await requireStaff();
  const documentId = String(form.get('documentId'));
  const { data: document, error } = await supabase.from('document_versions').select('storage_bucket,storage_object_path').eq('id',documentId).maybeSingle();
  if (error || !document) fail(path,error?.message ?? 'Document not found');
  const { data, error: signedError } = await supabase.storage.from(document.storage_bucket).createSignedUrl(document.storage_object_path, 60);
  if (signedError || !data?.signedUrl) fail(path,signedError?.message ?? 'Unable to create secure link');
  const { error: auditError } = await supabase.rpc('record_document_view',{p_document_id:documentId,p_context:{source:'staff_ui'}});
  if (auditError) fail(path,auditError.message);
  redirect(data.signedUrl);
}
