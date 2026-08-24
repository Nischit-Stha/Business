-- Harden document storage so object access is available only to the trusted server.
-- The browser/session JWT retains metadata reads but has no storage.objects policy.

drop policy if exists active_staff_read_private_documents on storage.objects;
drop policy if exists active_staff_upload_private_documents on storage.objects;

drop function if exists public.register_document_upload(uuid,text,text,text,text,text,bigint,text,date);

create or replace function public.register_document_upload(
  p_actor uuid,p_subject_id uuid,p_document_type text,p_bucket text,p_object_path text,p_original_filename text,
  p_mime_type text,p_file_size bigint,p_checksum_sha256 text,p_expiry_date date default null
) returns public.document_versions language plpgsql security definer set search_path='' as $$
declare parent_id uuid; prior public.document_versions; result public.document_versions;
begin
 if not exists(select 1 from public.staff_profiles where user_id=p_actor and is_active and status='ACTIVE' and role in ('ADMIN','STAFF'))
 then raise exception 'staff access required' using errcode='42501'; end if;
 if p_document_type not in ('DRIVER_LICENCE','PROOF_OF_ADDRESS','REGISTRATION','RWC') then raise exception 'unsupported document type' using errcode='22023'; end if;
 if p_mime_type not in ('application/pdf','image/jpeg','image/png') then raise exception 'unsupported file type' using errcode='22023'; end if;
 if p_file_size<1 or p_file_size>10485760 then raise exception 'file size exceeds 10 MiB limit' using errcode='22023'; end if;
 if p_document_type in ('DRIVER_LICENCE','REGISTRATION','RWC') and p_expiry_date is null then raise exception 'expiry date required' using errcode='22023'; end if;
 if p_original_filename is null or length(p_original_filename)>255 or p_original_filename ~ '[[:cntrl:]/\\]' then raise exception 'invalid filename' using errcode='22023'; end if;
 if p_checksum_sha256 !~ '^[0-9a-f]{64}$' or p_object_path ~ '(^/|\.\.|//|[\\])' then raise exception 'invalid object metadata' using errcode='22023'; end if;
 if p_document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS') then
   if p_bucket<>'customer-documents' or p_object_path !~ ('^customers/'||p_subject_id::text||'/'||lower(p_document_type)||'/[0-9a-f-]{36}\.(pdf|jpg|png)$') then raise exception 'invalid object path' using errcode='22023'; end if;
   insert into public.customer_documents(customer_id,document_type,status,expiry_date) values(p_subject_id,p_document_type,'SUBMITTED',p_expiry_date)
   on conflict(customer_id,document_type) do update set status='SUBMITTED',expiry_date=excluded.expiry_date,verified_by=null,verified_at=null returning id into parent_id;
   select * into prior from public.document_versions where customer_document_id=parent_id and status in ('SUBMITTED','VERIFIED') for update;
 else
   if p_bucket<>'vehicle-compliance-documents' or p_object_path !~ ('^vehicles/'||p_subject_id::text||'/'||lower(p_document_type)||'/[0-9a-f-]{36}\.(pdf|jpg|png)$') then raise exception 'invalid object path' using errcode='22023'; end if;
   insert into public.vehicle_compliance(vehicle_id,compliance_type,status,expires_at,verified_by) values(p_subject_id,p_document_type,'MISSING',p_expiry_date,null)
   on conflict(vehicle_id,compliance_type) do update set status='MISSING',expires_at=excluded.expires_at,verified_by=null returning id into parent_id;
   select * into prior from public.document_versions where vehicle_compliance_id=parent_id and status in ('SUBMITTED','VERIFIED') for update;
 end if;
 insert into public.document_versions(customer_document_id,vehicle_compliance_id,document_type,storage_bucket,storage_object_path,original_filename,mime_type,file_size,checksum_sha256,expiry_date,uploaded_by)
 values(case when p_document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS') then parent_id end,case when p_document_type in ('REGISTRATION','RWC') then parent_id end,p_document_type,p_bucket,p_object_path,p_original_filename,p_mime_type,p_file_size,p_checksum_sha256,p_expiry_date,p_actor) returning * into result;
 if prior.id is not null then
   update public.document_versions set status='SUPERSEDED',superseded_by=result.id,superseded_at=now() where id=prior.id;
   insert into public.document_access_events(actor,document_id,action,context) values(p_actor,prior.id,'SUPERSEDE',jsonb_build_object('superseded_by',result.id));
 end if;
 insert into public.document_access_events(actor,document_id,action,context) values(p_actor,result.id,'UPLOAD',jsonb_build_object('document_type',p_document_type,'file_size',p_file_size));
 return result;
end $$;

revoke all on function public.register_document_upload(uuid,uuid,text,text,text,text,text,bigint,text,date) from public,anon,authenticated;
grant execute on function public.register_document_upload(uuid,uuid,text,text,text,text,text,bigint,text,date) to service_role;
