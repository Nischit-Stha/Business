-- Private document storage, immutable versions, access audit, and controlled workflows.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('customer-documents','customer-documents',false,10485760,array['application/pdf','image/jpeg','image/png']),
  ('vehicle-compliance-documents','vehicle-compliance-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create table public.document_versions (
  id uuid primary key default gen_random_uuid(),
  customer_document_id uuid references public.customer_documents(id),
  vehicle_compliance_id uuid references public.vehicle_compliance(id),
  document_type text not null check(document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS','REGISTRATION','RWC')),
  storage_bucket text not null check(storage_bucket in ('customer-documents','vehicle-compliance-documents')),
  storage_object_path text not null unique,
  original_filename text not null check(length(original_filename) between 1 and 255),
  mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png')),
  file_size bigint not null check(file_size between 1 and 10485760),
  checksum_sha256 text not null check(checksum_sha256 ~ '^[0-9a-f]{64}$'),
  status text not null default 'SUBMITTED' check(status in ('SUBMITTED','VERIFIED','REJECTED','SUPERSEDED')),
  expiry_date date,
  uploaded_by uuid not null references public.staff_profiles(user_id),
  uploaded_at timestamptz not null default now(),
  verified_by uuid references public.staff_profiles(user_id), verified_at timestamptz,
  rejection_reason text,
  superseded_by uuid references public.document_versions(id), superseded_at timestamptz,
  check((customer_document_id is not null)::integer+(vehicle_compliance_id is not null)::integer=1),
  check((status='VERIFIED' and verified_by is not null and verified_at is not null) or status<>'VERIFIED'),
  check((status='REJECTED' and rejection_reason is not null) or status<>'REJECTED'),
  check((status='SUPERSEDED' and superseded_by is not null and superseded_at is not null) or status<>'SUPERSEDED'),
  check(storage_object_path !~ '(^/|\.\.|//|[\\])')
);
create index document_versions_customer_history on public.document_versions(customer_document_id,uploaded_at desc);
create index document_versions_vehicle_history on public.document_versions(vehicle_compliance_id,uploaded_at desc);

create table public.document_access_events (
  id bigint generated always as identity primary key,
  actor uuid not null references public.staff_profiles(user_id),
  document_id uuid not null references public.document_versions(id),
  action text not null check(action in ('UPLOAD','VIEW_LINK_GENERATED','VERIFY','REJECT','SUPERSEDE')),
  occurred_at timestamptz not null default now(), context jsonb not null default '{}'::jsonb,
  check(jsonb_typeof(context)='object')
);
create index document_access_events_document_time on public.document_access_events(document_id,occurred_at desc);

alter table public.document_versions enable row level security;
alter table public.document_access_events enable row level security;
create policy staff_read_document_versions on public.document_versions for select to authenticated using(app_private.is_staff());
create policy staff_read_document_events on public.document_access_events for select to authenticated using(app_private.is_staff());
revoke all on public.document_versions,public.document_access_events from anon,authenticated;
grant select on public.document_versions,public.document_access_events to authenticated;

-- Storage remains inaccessible to anon. Active staff may read an object only through
-- authenticated server calls; inserts/updates/deletes have no client policy.
create policy active_staff_read_private_documents on storage.objects for select to authenticated
using(bucket_id in ('customer-documents','vehicle-compliance-documents') and app_private.is_staff());
create policy active_staff_upload_private_documents on storage.objects for insert to authenticated
with check(bucket_id in ('customer-documents','vehicle-compliance-documents') and app_private.is_staff()
  and name !~ '(^/|\.\.|//|[\\])');

create or replace function public.register_document_upload(
  p_subject_id uuid,p_document_type text,p_bucket text,p_object_path text,p_original_filename text,
  p_mime_type text,p_file_size bigint,p_checksum_sha256 text,p_expiry_date date default null
) returns public.document_versions language plpgsql security definer set search_path='' as $$
declare parent_id uuid; prior public.document_versions; result public.document_versions;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_document_type not in ('DRIVER_LICENCE','PROOF_OF_ADDRESS','REGISTRATION','RWC') then raise exception 'unsupported document type' using errcode='22023'; end if;
 if p_mime_type not in ('application/pdf','image/jpeg','image/png') then raise exception 'unsupported file type' using errcode='22023'; end if;
 if p_file_size<1 or p_file_size>10485760 then raise exception 'file size exceeds 10 MiB limit' using errcode='22023'; end if;
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
 values(case when p_document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS') then parent_id end,case when p_document_type in ('REGISTRATION','RWC') then parent_id end,p_document_type,p_bucket,p_object_path,p_original_filename,p_mime_type,p_file_size,p_checksum_sha256,p_expiry_date,auth.uid()) returning * into result;
 if prior.id is not null then
   update public.document_versions set status='SUPERSEDED',superseded_by=result.id,superseded_at=now() where id=prior.id;
   insert into public.document_access_events(actor,document_id,action,context) values(auth.uid(),prior.id,'SUPERSEDE',jsonb_build_object('superseded_by',result.id));
 end if;
 insert into public.document_access_events(actor,document_id,action,context) values(auth.uid(),result.id,'UPLOAD',jsonb_build_object('document_type',p_document_type,'file_size',p_file_size));
 return result;
end $$;

create or replace function public.decide_document_version(p_document_id uuid,p_decision text,p_expiry_date date default null,p_reason text default null)
returns public.document_versions language plpgsql security definer set search_path='' as $$
declare result public.document_versions;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_decision not in ('VERIFIED','REJECTED') then raise exception 'invalid document decision' using errcode='22023'; end if;
 select * into result from public.document_versions where id=p_document_id and status='SUBMITTED' for update;
 if not found then raise exception 'submitted document not found'; end if;
 if p_decision='REJECTED' and nullif(btrim(p_reason),'') is null then raise exception 'rejection reason required' using errcode='22023'; end if;
 update public.document_versions set status=p_decision,expiry_date=p_expiry_date,
   verified_by=case when p_decision='VERIFIED' then auth.uid() end,verified_at=case when p_decision='VERIFIED' then now() end,
   rejection_reason=case when p_decision='REJECTED' then btrim(p_reason) end where id=p_document_id returning * into result;
 if result.customer_document_id is not null then
   update public.customer_documents set status=p_decision,expiry_date=p_expiry_date,verified_by=case when p_decision='VERIFIED' then auth.uid() end,verified_at=case when p_decision='VERIFIED' then now() end where id=result.customer_document_id;
 else
   update public.vehicle_compliance set status=case when p_decision='REJECTED' then 'MISSING' when p_expiry_date<current_date then 'EXPIRED' when p_expiry_date<=current_date+30 then 'EXPIRING_SOON' else 'VALID' end,
     expires_at=p_expiry_date,verified_by=case when p_decision='VERIFIED' then auth.uid() end where id=result.vehicle_compliance_id;
 end if;
 insert into public.document_access_events(actor,document_id,action,context) values(auth.uid(),result.id,case p_decision when 'VERIFIED' then 'VERIFY' else 'REJECT' end,jsonb_build_object('reason',case when p_decision='REJECTED' then btrim(p_reason) end));
 return result;
end $$;

create or replace function public.record_document_view(p_document_id uuid,p_context jsonb default '{}'::jsonb)
returns public.document_versions language plpgsql security definer set search_path='' as $$
declare result public.document_versions;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 select * into result from public.document_versions where id=p_document_id; if not found then raise exception 'document not found'; end if;
 insert into public.document_access_events(actor,document_id,action,context) values(auth.uid(),result.id,'VIEW_LINK_GENERATED',coalesce(p_context,'{}'::jsonb)); return result; end $$;

revoke all on function public.register_document_upload(uuid,text,text,text,text,text,bigint,text,date),public.decide_document_version(uuid,text,date,text),public.record_document_view(uuid,jsonb) from public;
grant execute on function public.register_document_upload(uuid,text,text,text,text,text,bigint,text,date),public.decide_document_version(uuid,text,date,text),public.record_document_view(uuid,jsonb) to authenticated;
