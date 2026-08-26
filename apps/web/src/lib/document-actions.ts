'use server';

import { createHash, randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireCustomer, requireStaff } from '@/lib/auth';
import { createPrivilegedStorageClient } from '@/lib/supabase/privileged-storage';
import { buildAgreementDocumentObjectPath, buildDocumentObjectPath, cleanDocumentFilename, detectDocumentType, DOCUMENT_MAX_BYTES, hasAllowedFilenameExtension, hasForbiddenDocumentContent } from '@/lib/document-validation';
import { scanUpload } from '@/lib/upload-scanner';
import { consumeActionBudget } from '@/lib/abuse-control';

async function validateScan(file:File,bytes:Uint8Array,mime:'application/pdf'|'image/jpeg'|'image/png',extension:string,path:string){
 if(!hasAllowedFilenameExtension(file.name,extension))fail(path,'Filename extension does not match the document content');
 if(hasForbiddenDocumentContent(bytes,mime))fail(path,'Document contains unsupported active or embedded content');
 const scan=await scanUpload(bytes);if(scan.verdict!=='clean')fail(path,'Document scanning is unavailable or rejected the upload');
}

function safeReturnPath(value: FormDataEntryValue | null) {
  const path = String(value ?? '');
  return /^\/(customers|fleet)\/[0-9a-f-]{36}$/.test(path) ? path : '/';
}
function fail(path: string, message: string): never { redirect(`${path}?error=${encodeURIComponent(message)}`); }
export async function uploadDocument(form: FormData) {
  const path = safeReturnPath(form.get('returnPath'));
  const file = form.get('file');
  if (!(file instanceof File) || file.size === 0) fail(path, 'Choose a non-empty document');
  if (file.size > DOCUMENT_MAX_BYTES) fail(path, 'File size exceeds 10 MiB limit');
  const bytes = new Uint8Array(await file.arrayBuffer());
  const detected = detectDocumentType(bytes);
  if (!detected) fail(path, 'Only genuine PDF, JPEG, and PNG files are supported');
  const [mime, rule] = detected;
  await validateScan(file,bytes,mime,rule.extension,path);
  const subjectId = String(form.get('subjectId'));
  const documentType = String(form.get('documentType'));
  const customer = ['DRIVER_LICENCE','PROOF_OF_ADDRESS'].includes(documentType);
  if (!/^[0-9a-f-]{36}$/.test(subjectId) || !['DRIVER_LICENCE','PROOF_OF_ADDRESS','REGISTRATION','RWC'].includes(documentType)) fail(path, 'Invalid document request');
  const bucket = customer ? 'customer-documents' : 'vehicle-compliance-documents';
  const objectPath = buildDocumentObjectPath(subjectId, documentType, randomUUID(), rule.extension);
  const checksum = createHash('sha256').update(bytes).digest('hex');
  const { user } = await requireStaff();
  const storage = createPrivilegedStorageClient();
  const { error: uploadError } = await storage.storage.from(bucket).upload(objectPath, bytes, { contentType: mime, upsert: false, cacheControl: 'private, max-age=0' });
  if (uploadError) fail(path, uploadError.message);
  const { error } = await storage.rpc('register_document_upload', {
    p_actor: user.id, p_subject_id: subjectId, p_document_type: documentType, p_bucket: bucket, p_object_path: objectPath,
    p_original_filename: cleanDocumentFilename(file.name), p_mime_type: mime, p_file_size: file.size,
    p_checksum_sha256: checksum, p_expiry_date: String(form.get('expiryDate') || '') || null,
  });
  if (error) { await storage.storage.from(bucket).remove([objectPath]); fail(path, error.message); }
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
  const { error: auditError } = await supabase.rpc('record_document_view',{p_document_id:documentId,p_context:{source:'staff_ui'}});
  if (auditError) fail(path,auditError.message);
  const storage = createPrivilegedStorageClient();
  const { data, error: signedError } = await storage.storage.from(document.storage_bucket).createSignedUrl(document.storage_object_path, 60);
  if (signedError || !data?.signedUrl) fail(path,signedError?.message ?? 'Unable to create secure link');
  redirect(data.signedUrl);
}

export async function uploadPortalDocument(form: FormData) {
  const file = form.get('file');
  if (!(file instanceof File) || file.size === 0) fail('/portal/documents', 'Choose a non-empty document');
  if (file.size > DOCUMENT_MAX_BYTES) fail('/portal/documents', 'File size exceeds 10 MiB limit');
  const bytes = new Uint8Array(await file.arrayBuffer()); const detected = detectDocumentType(bytes);
  if (!detected) fail('/portal/documents', 'Only genuine PDF, JPEG, and PNG files are supported');
  const [mime, rule] = detected; const documentType = String(form.get('documentType'));
  await validateScan(file,bytes,mime,rule.extension,'/portal/documents');
  if (!['DRIVER_LICENCE','PROOF_OF_ADDRESS'].includes(documentType)) fail('/portal/documents', 'Unsupported document type');
  const { supabase, user, customerId } = await requireCustomer(); try{await consumeActionBudget(supabase,'DOCUMENT_UPLOAD',10,3600);}catch(error){fail('/portal/documents',(error as Error).message);} const objectPath = buildDocumentObjectPath(customerId, documentType, randomUUID(), rule.extension);
  const storage = createPrivilegedStorageClient(); const checksum=createHash('sha256').update(bytes).digest('hex');
  const {error:uploadError}=await storage.storage.from('customer-documents').upload(objectPath,bytes,{contentType:mime,upsert:false,cacheControl:'private, max-age=0'});
  if(uploadError) fail('/portal/documents',uploadError.message);
  const {error}=await storage.rpc('register_portal_document_upload',{p_actor:user.id,p_document_type:documentType,p_bucket:'customer-documents',p_object_path:objectPath,p_original_filename:cleanDocumentFilename(file.name),p_mime_type:mime,p_file_size:file.size,p_checksum_sha256:checksum,p_expiry_date:String(form.get('expiryDate')||'')||null});
  if(error){await storage.storage.from('customer-documents').remove([objectPath]);fail('/portal/documents',error.message);} revalidatePath('/portal/documents');redirect('/portal/documents?uploaded=1');
}

export async function viewPortalDocument(form: FormData) {
  const {supabase}=await requireCustomer(); const id=String(form.get('documentId'));
  const {data,error}=await supabase.rpc('authorize_customer_document_access',{p_document_id:id}); const document=Array.isArray(data)?data[0]:data;
  if(error||!document) fail('/portal/documents',error?.message??'Document unavailable');
  const storage=createPrivilegedStorageClient(); const {data:link,error:linkError}=await storage.storage.from(document.storage_bucket).createSignedUrl(document.storage_object_path,60);
  if(linkError||!link?.signedUrl) fail('/portal/documents',linkError?.message??'Unable to create secure link'); redirect(link.signedUrl);
}

export async function reviewPortalDocument(form:FormData){const {supabase}=await requireStaff();const {error}=await supabase.rpc('review_portal_document',{p_document_id:String(form.get('documentId')),p_decision:String(form.get('decision')),p_reason:String(form.get('reason')||'')||null});if(error)fail('/operations/documents',error.message);revalidatePath('/operations/documents');redirect('/operations/documents');}

export async function uploadSignedAgreement(form:FormData){const customerId=String(form.get('customerId')),agreementId=String(form.get('agreementId'));const path=`/customers/${customerId}`;const file=form.get('file');if(!(file instanceof File)||file.size===0)fail(path,'Choose a signed PDF');if(file.size>DOCUMENT_MAX_BYTES)fail(path,'File size exceeds 10 MiB limit');const bytes=new Uint8Array(await file.arrayBuffer());const detected=detectDocumentType(bytes);if(!detected||detected[0]!=='application/pdf')fail(path,'Signed agreement must be a genuine PDF');await validateScan(file,bytes,'application/pdf','pdf',path);const {user}=await requireStaff();const objectPath=buildAgreementDocumentObjectPath(customerId,agreementId,randomUUID());const storage=createPrivilegedStorageClient();const {error:uploadError}=await storage.storage.from('customer-documents').upload(objectPath,bytes,{contentType:'application/pdf',upsert:false,cacheControl:'private, max-age=0'});if(uploadError)fail(path,'Document storage failed');const {error}=await storage.rpc('register_signed_agreement_upload',{p_actor:user.id,p_customer_id:customerId,p_agreement_id:agreementId,p_document_type:String(form.get('documentType')),p_object_path:objectPath,p_original_filename:cleanDocumentFilename(file.name),p_mime_type:'application/pdf',p_file_size:file.size,p_checksum_sha256:createHash('sha256').update(bytes).digest('hex')});if(error){await storage.storage.from('customer-documents').remove([objectPath]);fail(path,'Document registration failed');}revalidatePath(path);}
