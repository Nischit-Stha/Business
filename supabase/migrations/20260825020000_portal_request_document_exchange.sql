-- Two-way portal requests and secure customer document exchange.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED','MAINTENANCE_RECORD_CREATED','MAINTENANCE_RECORD_STATUS_CHANGED','MAINTENANCE_RECORD_COMPLETED','SERVICE_INTERVAL_CHANGED','COMPLIANCE_ATTENTION_REFRESHED','NOTIFICATION_CREATED','NOTIFICATION_CANCELLED','NOTIFICATION_RETRIED','NOTIFICATION_CLAIMED','NOTIFICATION_STATUS_CHANGED','NOTIFICATION_MANUALLY_QUEUED','CUSTOMER_PORTAL_ISSUE_SUBMITTED','CUSTOMER_PORTAL_RESCHEDULE_REQUESTED','CUSTOMER_PORTAL_PROFILE_CHANGE_REQUESTED','CUSTOMER_PORTAL_ACCESS_CHANGED',
  'PORTAL_REQUEST_SUBMITTED','PORTAL_REQUEST_ASSIGNED','PORTAL_REQUEST_APPROVED','PORTAL_REQUEST_DECLINED','PORTAL_REQUEST_COMPLETED','DOCUMENT_UPLOADED','DOCUMENT_REPLACED','DOCUMENT_ACCESS_ISSUED','AGREEMENT_DOCUMENT_UPLOADED'
));

update public.customer_portal_requests set status='SUBMITTED' where status='OPEN';
update public.customer_portal_requests set request_type='PHONE_CHANGE' where request_type='PROFILE_CONTACT_CHANGE' and requested_phone is not null and requested_email is null;
update public.customer_portal_requests set request_type='EMAIL_CHANGE' where request_type='PROFILE_CONTACT_CHANGE';
alter table public.customer_portal_requests drop constraint customer_portal_requests_request_type_check;
alter table public.customer_portal_requests drop constraint customer_portal_requests_status_check;
alter table public.customer_portal_requests drop constraint customer_portal_requests_check;
alter table public.customer_portal_requests
  alter column status set default 'SUBMITTED',
  add column assigned_staff_id uuid references public.staff_profiles(user_id),
  add column staff_response text check(staff_response is null or length(staff_response)<=1000),
  add column reviewed_at timestamptz,
  add column completed_at timestamptz,
  add column resolution_reason text check(resolution_reason is null or length(resolution_reason)<=1000),
  add constraint customer_portal_requests_request_type_check check(request_type in ('PICKUP_RESCHEDULE','RETURN_RESCHEDULE','PHONE_CHANGE','EMAIL_CHANGE','DOCUMENT_UPLOAD_REVIEW','GENERAL_REQUEST')),
  add constraint customer_portal_requests_status_check check(status in ('SUBMITTED','IN_REVIEW','APPROVED','DECLINED','COMPLETED','CANCELLED')),
  add constraint customer_portal_requests_payload_check check(
    (request_type='PICKUP_RESCHEDULE' and pickup_id is not null and return_id is null and requested_for is not null) or
    (request_type='RETURN_RESCHEDULE' and return_id is not null and pickup_id is null and requested_for is not null) or
    (request_type='PHONE_CHANGE' and requested_phone is not null and pickup_id is null and return_id is null) or
    (request_type='EMAIL_CHANGE' and requested_email is not null and pickup_id is null and return_id is null) or
    (request_type in ('DOCUMENT_UPLOAD_REVIEW','GENERAL_REQUEST') and pickup_id is null and return_id is null and nullif(btrim(customer_note),'') is not null)
  );
drop index customer_portal_requests_staff_queue;
create index customer_portal_requests_staff_queue on public.customer_portal_requests(status,created_at) where status in ('SUBMITTED','IN_REVIEW');

alter table public.notification_templates drop constraint notification_templates_template_key_check;
alter table public.notification_templates add constraint notification_templates_template_key_check check(template_key in ('PAYMENT_DUE','PAYMENT_OVERDUE','PAYMENT_RECEIVED','SERVICE_DUE','SERVICE_OVERDUE','LICENCE_EXPIRING','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_CREATED','ISSUE_STATUS_UPDATE','PORTAL_REQUEST_RECEIVED','PORTAL_REQUEST_APPROVED','PORTAL_REQUEST_DECLINED','DOCUMENT_RECEIVED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','AGREEMENT_AVAILABLE'));
alter table public.notifications drop constraint notifications_type_check;
alter table public.notifications add constraint notifications_type_check check(type in ('PAYMENT_DUE','PAYMENT_OVERDUE','PAYMENT_RECEIVED','SERVICE_DUE','SERVICE_OVERDUE','LICENCE_EXPIRING','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_CREATED','ISSUE_STATUS_UPDATE','PORTAL_REQUEST_RECEIVED','PORTAL_REQUEST_APPROVED','PORTAL_REQUEST_DECLINED','DOCUMENT_RECEIVED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','AGREEMENT_AVAILABLE'));
insert into public.notification_templates(template_key,channel,subject_template,message_template,allowed_variables) values
('PORTAL_REQUEST_RECEIVED','EMAIL','Request received','Hi {{customer_first_name}}, we received your {{request_type}} request.','{customer_first_name,request_type}'),
('PORTAL_REQUEST_APPROVED','EMAIL','Request approved','Hi {{customer_first_name}}, your {{request_type}} request was approved. {{staff_response}}','{customer_first_name,request_type,staff_response}'),
('PORTAL_REQUEST_DECLINED','EMAIL','Request update','Hi {{customer_first_name}}, your {{request_type}} request was declined. {{staff_response}}','{customer_first_name,request_type,staff_response}'),
('DOCUMENT_RECEIVED','EMAIL','Document received','Hi {{customer_first_name}}, we received your {{document_type}} for review.','{customer_first_name,document_type}'),
('DOCUMENT_VERIFIED','EMAIL','Document verified','Hi {{customer_first_name}}, your {{document_type}} has been verified.','{customer_first_name,document_type}'),
('DOCUMENT_REJECTED','EMAIL','Document needs attention','Hi {{customer_first_name}}, your {{document_type}} needs replacement. {{staff_response}}','{customer_first_name,document_type,staff_response}'),
('AGREEMENT_AVAILABLE','EMAIL','Agreement available','Hi {{customer_first_name}}, your signed agreement is now securely available in the Veera portal.','{customer_first_name}');

create or replace view public.portal_requests with (security_barrier=true) as
select id,request_type,status,staff_response,created_at,updated_at,completed_at
from public.customer_portal_requests where customer_id=app_private.portal_customer_id();
grant select on public.portal_requests to authenticated;

create or replace function app_private.portal_notification(p_key text,p_type text,p_customer uuid,p_data jsonb,p_actor uuid) returns uuid language sql security definer set search_path='' as $$
  select app_private.queue_notification(p_key,p_type,p_customer,p_data,now(),coalesce((select user_id from public.staff_profiles where user_id=p_actor and status='ACTIVE' and is_active),(select user_id from public.staff_profiles where status='ACTIVE' and is_active order by created_at limit 1)))
$$;

create or replace function public.submit_portal_request(p_type text,p_note text,p_phone text default null,p_email text default null) returns public.customer_portal_requests language plpgsql security definer set search_path='' as $$
declare cid uuid; r public.customer_portal_requests; c public.customers;
begin cid:=app_private.portal_customer_id(); if cid is null then raise exception 'active customer portal access required' using errcode='42501'; end if;
 if p_type not in ('PHONE_CHANGE','EMAIL_CHANGE','DOCUMENT_UPLOAD_REVIEW','GENERAL_REQUEST') then raise exception 'invalid request type' using errcode='22023'; end if;
 if p_type='PHONE_CHANGE' and (nullif(btrim(p_phone),'') is null or length(btrim(p_phone))>40) then raise exception 'valid phone is required' using errcode='22023'; end if;
 if p_type='EMAIL_CHANGE' and (nullif(btrim(p_email),'') is null or length(btrim(p_email))>254 or btrim(p_email) !~* '^[^@[:space:]]+@[^@[:space:]]+$') then raise exception 'valid email is required' using errcode='22023'; end if;
 if p_type in ('DOCUMENT_UPLOAD_REVIEW','GENERAL_REQUEST') and (nullif(btrim(p_note),'') is null or length(btrim(p_note))>500) then raise exception 'request detail is required' using errcode='22023'; end if;
 insert into public.customer_portal_requests(customer_id,request_type,requested_phone,requested_email,customer_note,created_by) values(cid,p_type,case when p_type='PHONE_CHANGE' then btrim(p_phone) end,case when p_type='EMAIL_CHANGE' then btrim(p_email) end,nullif(btrim(p_note),''),auth.uid()) returning * into r;
 select * into c from public.customers where id=cid; perform app_private.portal_notification('portal-request-received:'||r.id,'PORTAL_REQUEST_RECEIVED',cid,jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'request_type',initcap(replace(p_type,'_',' '))),auth.uid());
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PORTAL_REQUEST_SUBMITTED','customer_portal_request',r.id,jsonb_build_object('request_type',p_type)); return r; end $$;

create or replace function public.assign_portal_request(p_request_id uuid,p_staff_id uuid) returns public.customer_portal_requests language plpgsql security definer set search_path='' as $$
declare r public.customer_portal_requests;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if not exists(select 1 from public.staff_profiles where user_id=p_staff_id and status='ACTIVE' and is_active) then raise exception 'active staff member not found'; end if;
 update public.customer_portal_requests set assigned_staff_id=p_staff_id,status=case when status='SUBMITTED' then 'IN_REVIEW' else status end where id=p_request_id and status in ('SUBMITTED','IN_REVIEW','APPROVED') returning * into r; if not found then raise exception 'assignable request not found'; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PORTAL_REQUEST_ASSIGNED','customer_portal_request',r.id,jsonb_build_object('assigned_staff_id',p_staff_id)); return r; end $$;

create or replace function public.decide_portal_request(p_request_id uuid,p_decision text,p_response text,p_resolution_reason text default null) returns public.customer_portal_requests language plpgsql security definer set search_path='' as $$
declare r public.customer_portal_requests; c public.customers; ntype text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_decision not in ('APPROVED','DECLINED') then raise exception 'invalid decision'; end if;
 if nullif(btrim(p_response),'') is null or length(btrim(p_response))>1000 then raise exception 'customer-safe response required'; end if;
 select * into r from public.customer_portal_requests where id=p_request_id and status in ('SUBMITTED','IN_REVIEW') for update; if not found then raise exception 'reviewable request not found'; end if;
 -- Schedule changes are applied only through existing controlled scheduling functions.
 if p_decision='APPROVED' and r.request_type in ('PICKUP_RESCHEDULE','RETURN_RESCHEDULE') then
   if r.requested_for<=now() then raise exception 'requested schedule is no longer in the future'; end if;
   if exists(select 1 from public.pickup_checklists p join public.vehicles v on v.id=p.vehicle_id where p.id=r.pickup_id and (p.status in ('COMPLETED','CANCELLED') or v.operational_status not in ('AVAILABLE','PICKUP_PENDING'))) then raise exception 'pickup operational state does not allow rescheduling'; end if;
   if exists(select 1 from public.return_checklists q join public.vehicle_assignments a on a.id=q.assignment_id where q.id=r.return_id and (q.status in ('COMPLETED','CANCELLED') or a.assignment_status<>'ACTIVE')) then raise exception 'return operational state does not allow rescheduling'; end if;
   if exists(select 1 from public.pickup_checklists p where p.id<>coalesce(r.pickup_id,'00000000-0000-0000-0000-000000000000') and p.status not in ('COMPLETED','CANCELLED') and p.scheduled_at between r.requested_for-interval '2 hours' and r.requested_for+interval '2 hours') or exists(select 1 from public.return_checklists q where q.id<>coalesce(r.return_id,'00000000-0000-0000-0000-000000000000') and q.status not in ('COMPLETED','CANCELLED') and q.scheduled_at between r.requested_for-interval '2 hours' and r.requested_for+interval '2 hours') then raise exception 'requested schedule conflicts with another operation'; end if;
 end if;
 if p_decision='APPROVED' and r.request_type='PICKUP_RESCHEDULE' then perform public.schedule_pickup((select agreement_id from public.pickup_checklists where id=r.pickup_id),r.requested_for,'Approved portal request '||r.id);
 elsif p_decision='APPROVED' and r.request_type='RETURN_RESCHEDULE' then perform public.schedule_return((select assignment_id from public.return_checklists where id=r.return_id),r.requested_for,'Approved portal request '||r.id); end if;
 update public.customer_portal_requests set status=p_decision,staff_response=btrim(p_response),resolution_reason=nullif(btrim(p_resolution_reason),''),reviewed_at=now(),assigned_staff_id=coalesce(assigned_staff_id,auth.uid()) where id=r.id returning * into r;
 select * into c from public.customers where id=r.customer_id; ntype:=case p_decision when 'APPROVED' then 'PORTAL_REQUEST_APPROVED' else 'PORTAL_REQUEST_DECLINED' end;
 perform app_private.portal_notification('portal-request-decision:'||r.id,ntype,r.customer_id,jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'request_type',initcap(replace(r.request_type,'_',' ')),'staff_response',r.staff_response),auth.uid());
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),case p_decision when 'APPROVED' then 'PORTAL_REQUEST_APPROVED' else 'PORTAL_REQUEST_DECLINED' end,'customer_portal_request',r.id,jsonb_build_object('request_type',r.request_type)); return r; end $$;

create or replace function public.complete_portal_request(p_request_id uuid,p_response text default null) returns public.customer_portal_requests language plpgsql security definer set search_path='' as $$
declare r public.customer_portal_requests; begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.customer_portal_requests set status='COMPLETED',completed_at=now(),staff_response=coalesce(nullif(btrim(p_response),''),staff_response) where id=p_request_id and status='APPROVED' returning * into r; if not found then raise exception 'approved request not found'; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'PORTAL_REQUEST_COMPLETED','customer_portal_request',r.id,'{}'); return r; end $$;

revoke all on function public.submit_portal_request(text,text,text,text),public.assign_portal_request(uuid,uuid),public.decide_portal_request(uuid,text,text,text),public.complete_portal_request(uuid,text) from public;
grant execute on function public.submit_portal_request(text,text,text,text),public.assign_portal_request(uuid,uuid),public.decide_portal_request(uuid,text,text,text),public.complete_portal_request(uuid,text) to authenticated;

-- Expand immutable versions for portal uploads and signed agreements.
alter table public.document_versions drop constraint document_versions_document_type_check;
alter table public.document_versions drop constraint document_versions_status_check;
alter table public.document_versions drop constraint document_versions_uploaded_by_fkey;
alter table public.document_versions add constraint document_versions_uploaded_by_fkey foreign key(uploaded_by) references auth.users(id);
alter table public.document_versions add column agreement_id uuid references public.agreements(id), add column customer_id uuid references public.customers(id), add column customer_safe_reason text check(customer_safe_reason is null or length(customer_safe_reason)<=500);
update public.document_versions v set customer_id=d.customer_id from public.customer_documents d where v.customer_document_id=d.id;
alter table public.document_versions add constraint document_versions_document_type_check check(document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS','REGISTRATION','RWC','SIGNED_RENTAL_AGREEMENT','RENT_TO_OWN_AGREEMENT','RECEIPT','OTHER_CUSTOMER_DOCUMENT'));
alter table public.document_versions add constraint document_versions_status_check check(status in ('SUBMITTED','PENDING_REVIEW','VERIFIED','REJECTED','SUPERSEDED','REPLACED','ARCHIVED'));
create index document_versions_pending_review on public.document_versions(uploaded_at) where status='PENDING_REVIEW';

drop view public.portal_documents;
create view public.portal_documents with (security_barrier=true) as
select id,document_type,case status when 'SUBMITTED' then 'PENDING_REVIEW' when 'SUPERSEDED' then 'REPLACED' else status end status,expiry_date,uploaded_at created_at,verified_at,customer_safe_reason
from public.document_versions where customer_id=app_private.portal_customer_id() and status not in ('SUPERSEDED','REPLACED','ARCHIVED') and document_type in ('DRIVER_LICENCE','PROOF_OF_ADDRESS','SIGNED_RENTAL_AGREEMENT','RENT_TO_OWN_AGREEMENT','RECEIPT','OTHER_CUSTOMER_DOCUMENT')
union all select d.id,d.document_type,case d.status when 'SUBMITTED' then 'PENDING_REVIEW' else d.status end,d.expiry_date,d.created_at,d.verified_at,null::text from public.customer_documents d where d.customer_id=app_private.portal_customer_id() and not exists(select 1 from public.document_versions v where v.customer_document_id=d.id);
grant select on public.portal_documents to authenticated;

create or replace function public.authorize_customer_document_access(p_document_id uuid) returns table(storage_bucket text,storage_object_path text) language plpgsql security definer set search_path='' as $$
declare cid uuid; begin cid:=app_private.portal_customer_id(); if cid is null then raise exception 'active customer portal access required' using errcode='42501'; end if;
 return query select d.storage_bucket,d.storage_object_path from public.document_versions d where d.id=p_document_id and d.customer_id=cid and d.status='VERIFIED'; if not found then raise exception 'approved document not found' using errcode='42501'; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'DOCUMENT_ACCESS_ISSUED','document_version',p_document_id,jsonb_build_object('audience','CUSTOMER')); end $$;

create or replace function public.register_portal_document_upload(p_actor uuid,p_document_type text,p_bucket text,p_object_path text,p_original_filename text,p_mime_type text,p_file_size bigint,p_checksum_sha256 text,p_expiry_date date default null) returns public.document_versions language plpgsql security definer set search_path='' as $$
declare cid uuid; parent_id uuid; prior public.document_versions; result public.document_versions; c public.customers;
begin select customer_id into cid from public.customer_portal_accounts where user_id=p_actor and status='ACTIVE'; if cid is null then raise exception 'active customer portal access required' using errcode='42501'; end if;
 if p_document_type not in ('DRIVER_LICENCE','PROOF_OF_ADDRESS') then raise exception 'unsupported portal document type' using errcode='22023'; end if;
 if p_mime_type not in ('application/pdf','image/jpeg','image/png') or p_file_size<1 or p_file_size>10485760 then raise exception 'invalid file'; end if;
 if p_original_filename is null or length(p_original_filename)>255 or p_original_filename ~ '[[:cntrl:]/\\]' or p_checksum_sha256 !~ '^[0-9a-f]{64}$' then raise exception 'invalid object metadata'; end if;
 if p_bucket<>'customer-documents' or p_object_path !~ ('^customers/'||cid::text||'/'||lower(p_document_type)||'/[0-9a-f-]{36}\.(pdf|jpg|png)$') then raise exception 'invalid object path' using errcode='22023'; end if;
 if p_document_type='DRIVER_LICENCE' and p_expiry_date is null then raise exception 'expiry date required'; end if;
 insert into public.customer_documents(customer_id,document_type,status,expiry_date) values(cid,p_document_type,'SUBMITTED',p_expiry_date) on conflict(customer_id,document_type) do update set status='SUBMITTED',expiry_date=excluded.expiry_date,verified_by=null,verified_at=null returning id into parent_id;
 select * into prior from public.document_versions where customer_document_id=parent_id and status in ('SUBMITTED','PENDING_REVIEW','VERIFIED') for update;
 insert into public.document_versions(customer_document_id,customer_id,document_type,storage_bucket,storage_object_path,original_filename,mime_type,file_size,checksum_sha256,status,expiry_date,uploaded_by) values(parent_id,cid,p_document_type,p_bucket,p_object_path,p_original_filename,p_mime_type,p_file_size,p_checksum_sha256,'PENDING_REVIEW',p_expiry_date,p_actor) returning * into result;
 if prior.id is not null then update public.document_versions set status='REPLACED',superseded_by=result.id,superseded_at=now() where id=prior.id; insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,'DOCUMENT_REPLACED','document_version',prior.id,jsonb_build_object('replacement_id',result.id)); end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,'DOCUMENT_UPLOADED','document_version',result.id,jsonb_build_object('document_type',p_document_type));
 select * into c from public.customers where id=cid; perform app_private.portal_notification('document-received:'||result.id,'DOCUMENT_RECEIVED',cid,jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'document_type',initcap(replace(p_document_type,'_',' '))),p_actor); return result; end $$;

create or replace function public.review_portal_document(p_document_id uuid,p_decision text,p_reason text default null) returns public.document_versions language plpgsql security definer set search_path='' as $$
declare d public.document_versions; c public.customers; begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_decision not in ('VERIFIED','REJECTED','REPLACED') then raise exception 'invalid decision'; end if; if p_decision in ('REJECTED','REPLACED') and nullif(btrim(p_reason),'') is null then raise exception 'customer-safe reason required'; end if;
 update public.document_versions set status=p_decision,verified_by=case when p_decision='VERIFIED' then auth.uid() end,verified_at=case when p_decision='VERIFIED' then now() end,customer_safe_reason=case when p_decision<>'VERIFIED' then btrim(p_reason) end,rejection_reason=case when p_decision<>'VERIFIED' then btrim(p_reason) end where id=p_document_id and status='PENDING_REVIEW' returning * into d; if not found then raise exception 'pending document not found'; end if;
 update public.customer_documents set status=case when p_decision='VERIFIED' then 'VERIFIED' else 'REJECTED' end,verified_by=case when p_decision='VERIFIED' then auth.uid() end,verified_at=case when p_decision='VERIFIED' then now() end where id=d.customer_document_id;
 insert into public.document_access_events(actor,document_id,action,context) values(auth.uid(),d.id,case when p_decision='VERIFIED' then 'VERIFY' else 'REJECT' end,jsonb_build_object('customer_safe_reason',d.customer_safe_reason));
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),case when p_decision='VERIFIED' then 'DOCUMENT_VERIFIED' else 'DOCUMENT_REJECTED' end,'document_version',d.id,jsonb_build_object('decision',p_decision));
 select * into c from public.customers where id=d.customer_id; perform app_private.portal_notification('document-decision:'||d.id,case when p_decision='VERIFIED' then 'DOCUMENT_VERIFIED' else 'DOCUMENT_REJECTED' end,d.customer_id,case when p_decision='VERIFIED' then jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'document_type',initcap(replace(d.document_type,'_',' '))) else jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'document_type',initcap(replace(d.document_type,'_',' ')),'staff_response',coalesce(d.customer_safe_reason,'')) end,auth.uid()); return d; end $$;

revoke all on function public.authorize_customer_document_access(uuid),public.register_portal_document_upload(uuid,text,text,text,text,text,bigint,text,date),public.review_portal_document(uuid,text,text) from public;
grant execute on function public.authorize_customer_document_access(uuid),public.review_portal_document(uuid,text,text) to authenticated;
grant execute on function public.register_portal_document_upload(uuid,text,text,text,text,text,bigint,text,date) to service_role;

create or replace function public.register_signed_agreement_upload(p_actor uuid,p_customer_id uuid,p_agreement_id uuid,p_document_type text,p_object_path text,p_original_filename text,p_mime_type text,p_file_size bigint,p_checksum_sha256 text) returns public.document_versions language plpgsql security definer set search_path='' as $$
declare d public.document_versions; c public.customers;
begin if not exists(select 1 from public.staff_profiles where user_id=p_actor and status='ACTIVE' and is_active) then raise exception 'staff access required' using errcode='42501'; end if;
 if p_document_type not in ('SIGNED_RENTAL_AGREEMENT','RENT_TO_OWN_AGREEMENT') or not exists(select 1 from public.agreements where id=p_agreement_id and customer_id=p_customer_id) then raise exception 'valid customer agreement is required'; end if;
 if p_mime_type<>'application/pdf' or p_file_size<1 or p_file_size>10485760 or p_checksum_sha256 !~ '^[0-9a-f]{64}$' then raise exception 'signed agreement must be a PDF up to 10 MiB'; end if;
 if p_object_path !~ ('^customers/'||p_customer_id::text||'/agreements/'||p_agreement_id::text||'/[0-9a-f-]{36}\.pdf$') or p_original_filename ~ '[[:cntrl:]/\\]' then raise exception 'invalid object metadata'; end if;
 update public.document_versions set status='REPLACED',superseded_at=now() where agreement_id=p_agreement_id and document_type=p_document_type and status='VERIFIED';
 insert into public.document_versions(customer_id,agreement_id,document_type,storage_bucket,storage_object_path,original_filename,mime_type,file_size,checksum_sha256,status,uploaded_by,verified_by,verified_at) values(p_customer_id,p_agreement_id,p_document_type,'customer-documents',p_object_path,p_original_filename,p_mime_type,p_file_size,p_checksum_sha256,'VERIFIED',p_actor,p_actor,now()) returning * into d;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,'AGREEMENT_DOCUMENT_UPLOADED','document_version',d.id,jsonb_build_object('agreement_id',p_agreement_id)); select * into c from public.customers where id=p_customer_id; perform app_private.portal_notification('agreement-available:'||d.id,'AGREEMENT_AVAILABLE',p_customer_id,jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1)),p_actor); return d; end $$;
revoke all on function public.register_signed_agreement_upload(uuid,uuid,uuid,text,text,text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.register_signed_agreement_upload(uuid,uuid,uuid,text,text,text,text,bigint,text) to service_role;

alter table public.operational_exceptions drop constraint operational_exceptions_exception_type_check;
-- Exception types are written only by server-controlled functions. Earlier migrations
-- accumulated a brittle enum check; the workflow registry now lives in those functions.
create or replace function public.refresh_portal_exchange_exceptions() returns integer language plpgsql security definer set search_path='' as $$
declare x record;n integer:=0;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.operational_exceptions e set status='RESOLVED',resolved_at=now(),resolution_note='Condition cleared automatically' where e.status<>'RESOLVED' and e.exception_type in ('PORTAL_REQUEST_DELAYED','DOCUMENT_REPEATEDLY_REJECTED','REQUIRED_CUSTOMER_DOCUMENT_MISSING');
 for x in select * from public.customer_portal_requests where status in ('SUBMITTED','IN_REVIEW') and created_at<now()-interval '48 hours' loop perform app_private.upsert_exception('PORTAL_REQUEST_DELAYED','MEDIUM','customer_portal_request',x.id,'portal-request-delayed:'||x.id,'Customer portal request has waited more than 48 hours',jsonb_build_object('customer_id',x.customer_id),false,auth.uid());n:=n+1;end loop;
 for x in select customer_id,document_type,count(*) rejects from public.document_versions where status in ('REJECTED','REPLACED') group by customer_id,document_type having count(*)>=2 loop perform app_private.upsert_exception('DOCUMENT_REPEATEDLY_REJECTED','HIGH','customer',x.customer_id,'document-rejections:'||x.customer_id||':'||x.document_type,'Customer document has been rejected repeatedly',jsonb_build_object('document_type',x.document_type,'rejections',x.rejects),true,auth.uid());n:=n+1;end loop;
 for x in select distinct a.customer_id from public.agreements a where a.status in ('ACTIVE','PENDING_SIGNATURE') and (not exists(select 1 from public.customer_documents d where d.customer_id=a.customer_id and d.document_type='DRIVER_LICENCE' and d.status='VERIFIED' and (d.expiry_date is null or d.expiry_date>=current_date)) or not exists(select 1 from public.customer_documents d where d.customer_id=a.customer_id and d.document_type='PROOF_OF_ADDRESS' and d.status='VERIFIED')) loop perform app_private.upsert_exception('REQUIRED_CUSTOMER_DOCUMENT_MISSING','HIGH','customer',x.customer_id,'required-document-missing:'||x.customer_id,'Required customer document is missing for an active or pending agreement','{}',true,auth.uid());n:=n+1;end loop;return n;end $$;
revoke all on function public.refresh_portal_exchange_exceptions() from public;grant execute on function public.refresh_portal_exchange_exceptions() to authenticated;
