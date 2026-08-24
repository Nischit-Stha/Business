-- Provider-neutral notification and reminder engine. No production provider is enabled.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED','MAINTENANCE_RECORD_CREATED','MAINTENANCE_RECORD_STATUS_CHANGED','MAINTENANCE_RECORD_COMPLETED','SERVICE_INTERVAL_CHANGED','COMPLIANCE_ATTENTION_REFRESHED',
  'NOTIFICATION_CREATED','NOTIFICATION_CANCELLED','NOTIFICATION_RETRIED','NOTIFICATION_CLAIMED','NOTIFICATION_STATUS_CHANGED','NOTIFICATION_MANUALLY_QUEUED'
));

create table public.notification_templates (
  template_key text primary key check(template_key in ('PAYMENT_DUE','PAYMENT_OVERDUE','PAYMENT_RECEIVED','SERVICE_DUE','SERVICE_OVERDUE','LICENCE_EXPIRING','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_CREATED','ISSUE_STATUS_UPDATE')),
  channel text not null check(channel in ('SMS','EMAIL','WHATSAPP','INTERNAL')),
  subject_template text,
  message_template text not null check(btrim(message_template)<>''),
  allowed_variables text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(channel<>'EMAIL' or btrim(coalesce(subject_template,''))<>'')
);
create trigger notification_templates_touch before update on public.notification_templates for each row execute function app_private.touch_updated_at();

insert into public.notification_templates(template_key,channel,subject_template,message_template,allowed_variables) values
('PAYMENT_DUE','SMS',null,'Hi {{customer_first_name}}, your Veera payment of ${{amount}} is due on {{due_date}}.','{customer_first_name,amount,due_date}'),
('PAYMENT_OVERDUE','SMS',null,'Hi {{customer_first_name}}, your Veera payment of ${{amount}} was due on {{due_date}}. Please contact our team if you need help.','{customer_first_name,amount,due_date}'),
('PAYMENT_RECEIVED','SMS',null,'Hi {{customer_first_name}}, Veera received your payment of ${{amount}}. Thank you.','{customer_first_name,amount}'),
('SERVICE_DUE','SMS',null,'Hi {{customer_first_name}}, {{vehicle_registration}} ({{vehicle_make_model}}) is due for service in {{service_kilometres_remaining}} km. Please contact Veera to arrange it.','{customer_first_name,vehicle_registration,vehicle_make_model,service_kilometres_remaining}'),
('SERVICE_OVERDUE','SMS',null,'Hi {{customer_first_name}}, service for {{vehicle_registration}} ({{vehicle_make_model}}) is overdue. Please contact Veera today.','{customer_first_name,vehicle_registration,vehicle_make_model,service_kilometres_remaining}'),
('LICENCE_EXPIRING','EMAIL','Driver licence expiry reminder','Hi {{customer_first_name}}, your driver licence expires on {{due_date}}. Please contact Veera to keep your records current.','{customer_first_name,due_date}'),
('LICENCE_EXPIRED','EMAIL','Driver licence expired','Hi {{customer_first_name}}, our records show your driver licence expired on {{due_date}}. Please contact Veera.','{customer_first_name,due_date}'),
('PICKUP_REMINDER','SMS',null,'Hi {{customer_first_name}}, your pickup for {{vehicle_registration}} is scheduled for {{scheduled_pickup_time}}.','{customer_first_name,vehicle_registration,scheduled_pickup_time}'),
('RETURN_REMINDER','SMS',null,'Hi {{customer_first_name}}, your return for {{vehicle_registration}} is scheduled for {{scheduled_return_time}}.','{customer_first_name,vehicle_registration,scheduled_return_time}'),
('ISSUE_CREATED','SMS',null,'Hi {{customer_first_name}}, Veera has opened an issue for {{vehicle_registration}}. Our team will keep you updated.','{customer_first_name,vehicle_registration}'),
('ISSUE_STATUS_UPDATE','SMS',null,'Hi {{customer_first_name}}, the issue for {{vehicle_registration}} is now {{issue_status}}.','{customer_first_name,vehicle_registration,issue_status}');

create table public.notification_settings (
  id boolean primary key default true check(id),
  payment_stages integer[] not null default '{0,1,3,7}', licence_stages integer[] not null default '{30,14,7,0}',
  pickup_hours integer[] not null default '{24,0}', return_hours integer[] not null default '{24,0}',
  max_retries integer not null default 3 check(max_retries between 1 and 5),
  updated_by uuid references public.staff_profiles(user_id), updated_at timestamptz not null default now()
);
insert into public.notification_settings(id) values(true);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id), vehicle_id uuid references public.vehicles(id), agreement_id uuid references public.agreements(id), issue_id uuid references public.vehicle_issues(id),
  type text not null check(type in ('PAYMENT_DUE','PAYMENT_OVERDUE','PAYMENT_RECEIVED','SERVICE_DUE','SERVICE_OVERDUE','LICENCE_EXPIRING','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_CREATED','ISSUE_STATUS_UPDATE')),
  channel text not null check(channel in ('SMS','EMAIL','WHATSAPP','INTERNAL')), template_key text not null references public.notification_templates(template_key),
  subject text, rendered_message text not null check(btrim(rendered_message)<>''), scheduled_for timestamptz not null,
  sent_at timestamptz, delivered_at timestamptz, failed_at timestamptz,
  status text not null check(status in ('QUEUED','SCHEDULED','SENDING','SENT','DELIVERED','FAILED','CANCELLED','SUPPRESSED')),
  retry_count integer not null default 0 check(retry_count between 0 and 5), failure_reason text check(length(failure_reason)<=500), provider_message_id text,
  created_by uuid not null references public.staff_profiles(user_id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  dedup_key text not null unique, recipient text, claim_token uuid, claim_expires_at timestamptz, max_retries integer not null check(max_retries between 1 and 5), manual boolean not null default false
);
create index notifications_due_queue on public.notifications(status,scheduled_for) where status in ('QUEUED','SCHEDULED','SENDING');
create index notifications_customer_history on public.notifications(customer_id,created_at desc);
create trigger notifications_touch before update on public.notifications for each row execute function app_private.touch_updated_at();
create or replace function app_private.protect_sent_notification() returns trigger language plpgsql set search_path='' as $$ begin if old.status in ('SENT','DELIVERED') and (new.rendered_message is distinct from old.rendered_message or new.subject is distinct from old.subject or new.customer_id is distinct from old.customer_id or new.type is distinct from old.type) then raise exception 'sent notification history is immutable' using errcode='42501'; end if; return new; end $$;
create trigger notifications_protect_sent before update on public.notifications for each row execute function app_private.protect_sent_notification();

alter table public.notification_templates enable row level security; alter table public.notification_settings enable row level security; alter table public.notifications enable row level security;
create policy staff_read_notification_templates on public.notification_templates for select to authenticated using(app_private.is_staff());
create policy staff_read_notification_settings on public.notification_settings for select to authenticated using(app_private.is_staff());
create policy staff_read_notifications on public.notifications for select to authenticated using(app_private.is_staff());
revoke all on public.notification_templates,public.notification_settings,public.notifications from anon,authenticated;
grant select on public.notification_templates,public.notification_settings,public.notifications to authenticated;

create or replace function app_private.render_notification(p_template text,p_data jsonb,p_allowed text[]) returns text language plpgsql immutable set search_path='' as $$
declare k text; result text:=p_template; token text;
begin
 if jsonb_typeof(p_data)<>'object' then raise exception 'template data must be an object'; end if;
 for k in select jsonb_object_keys(p_data) loop if not k=any(p_allowed) then raise exception 'unsafe template variable: %',k using errcode='22023'; end if; end loop;
 for token in select (regexp_matches(p_template,'\{\{([a-z_]+)\}\}','g'))[1] loop
   if not token=any(p_allowed) or not p_data ? token then raise exception 'missing or unsafe template variable: %',token using errcode='22023'; end if;
   result:=replace(result,'{{'||token||'}}',p_data->>token);
 end loop;
 if result ~ '\{\{' then raise exception 'unresolved template variable' using errcode='22023'; end if;
 return result;
end $$;

create or replace function app_private.queue_notification(p_dedup_key text,p_type text,p_customer_id uuid,p_data jsonb,p_scheduled_for timestamptz,p_actor uuid,p_vehicle_id uuid default null,p_agreement_id uuid default null,p_issue_id uuid default null,p_manual boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare t public.notification_templates; c public.customers; pref public.customer_communication_preferences; nid uuid; target text; initial_status text; reason text; retries int;
begin
 select * into t from public.notification_templates where template_key=p_type and is_active; if not found then raise exception 'active notification template not found'; end if;
 if p_customer_id is not null then select * into c from public.customers where id=p_customer_id; if not found then raise exception 'customer not found'; end if; end if;
 if t.channel='SMS' then target:=nullif(btrim(c.phone),''); elsif t.channel='EMAIL' then target:=nullif(btrim(c.email),''); else target:='internal'; end if;
 select * into pref from public.customer_communication_preferences where customer_id=p_customer_id;
 if (t.channel='SMS' and coalesce(pref.sms_opt_out,false)) or (t.channel='EMAIL' and coalesce(pref.email_opt_out,false)) then reason:='Customer communication preference';
 elsif t.channel not in ('INTERNAL') and target is null then reason:='Missing customer contact'; end if;
 initial_status:=case when reason is not null then 'SUPPRESSED' when p_scheduled_for>now() then 'SCHEDULED' else 'QUEUED' end;
 select max_retries into retries from public.notification_settings where id;
 insert into public.notifications(customer_id,vehicle_id,agreement_id,issue_id,type,channel,template_key,subject,rendered_message,scheduled_for,status,failure_reason,created_by,dedup_key,recipient,max_retries,manual)
 values(p_customer_id,p_vehicle_id,p_agreement_id,p_issue_id,p_type,t.channel,t.template_key,case when t.subject_template is null then null else app_private.render_notification(t.subject_template,p_data,t.allowed_variables) end,app_private.render_notification(t.message_template,p_data,t.allowed_variables),p_scheduled_for,initial_status,reason,p_actor,p_dedup_key,target,retries,p_manual)
 on conflict(dedup_key) do nothing returning id into nid;
 if nid is not null then insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(p_actor,case when p_manual then 'NOTIFICATION_MANUALLY_QUEUED' else 'NOTIFICATION_CREATED' end,'notification',nid,jsonb_build_object('type',p_type,'status',initial_status)); end if;
 return nid;
end $$;

create or replace function public.generate_notifications(p_as_of timestamptz default now()) returns integer language plpgsql security definer set search_path='' as $$
declare r record; n int:=0; nid uuid; stage int; dtype text; sched timestamptz;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 -- Cancel obsolete, unsent work before generating current conditions.
 update public.notifications x set status='CANCELLED',failure_reason='Payment obligation paid',claim_token=null,claim_expires_at=null where x.type in ('PAYMENT_DUE','PAYMENT_OVERDUE') and x.status in ('QUEUED','SCHEDULED','SENDING') and exists(select 1 from public.payment_schedule_items s where s.id=(split_part(x.dedup_key,':',2))::uuid and s.status in ('PAID','WAIVED'));
 update public.notifications x set status='CANCELLED',failure_reason='Service condition cleared',claim_token=null,claim_expires_at=null where x.type in ('SERVICE_DUE','SERVICE_OVERDUE') and x.status in ('QUEUED','SCHEDULED','SENDING') and not exists(select 1 from public.vehicle_maintenance_status s where s.vehicle_id=x.vehicle_id and s.status in ('DUE_SOON','OVERDUE'));
 update public.notifications x set status='CANCELLED',failure_reason='Schedule completed or cancelled',claim_token=null,claim_expires_at=null where x.type='PICKUP_REMINDER' and x.status in ('QUEUED','SCHEDULED','SENDING') and exists(select 1 from public.pickup_checklists p where p.id=(split_part(x.dedup_key,':',2))::uuid and p.status in ('COMPLETED','CANCELLED'));
 update public.notifications x set status='CANCELLED',failure_reason='Schedule completed or cancelled',claim_token=null,claim_expires_at=null where x.type='RETURN_REMINDER' and x.status in ('QUEUED','SCHEDULED','SENDING') and exists(select 1 from public.return_checklists p where p.id=(split_part(x.dedup_key,':',2))::uuid and p.status in ('COMPLETED','CANCELLED'));
 for r in select s.*,a.customer_id,a.vehicle_id,c.full_name from public.payment_schedule_items s join public.agreements a on a.id=s.agreement_id and a.status='ACTIVE' join public.customers c on c.id=a.customer_id where s.status not in ('PAID','WAIVED') loop
   foreach stage in array (select payment_stages from public.notification_settings where id) loop
     if (p_as_of at time zone 'Australia/Melbourne')::date >= r.due_date+stage then dtype:=case when stage=0 then 'PAYMENT_DUE' else 'PAYMENT_OVERDUE' end; sched:=(r.due_date+stage)::timestamp at time zone 'Australia/Melbourne';
       nid:=app_private.queue_notification('payment:'||r.id||':'||stage,dtype,r.customer_id,jsonb_build_object('customer_first_name',split_part(r.full_name,' ',1),'amount',to_char(r.amount_due-r.amount_paid,'FM999999990.00'),'due_date',to_char(r.due_date,'DD Mon YYYY')),sched,auth.uid(),r.vehicle_id,r.agreement_id); if nid is not null then n:=n+1; end if;
     end if;
   end loop;
 end loop;
 for r in select c.id,c.full_name,c.licence_expiry from public.customers c where c.status='ACTIVE' and c.licence_expiry is not null and exists(select 1 from public.agreements a where a.customer_id=c.id and a.status in ('ACTIVE','PENDING_SIGNATURE')) loop
   foreach stage in array (select licence_stages from public.notification_settings where id) loop
    if (p_as_of at time zone 'Australia/Melbourne')::date >= r.licence_expiry-stage then dtype:=case when stage=0 then 'LICENCE_EXPIRED' else 'LICENCE_EXPIRING' end; nid:=app_private.queue_notification('licence:'||r.id||':'||r.licence_expiry||':'||stage,dtype,r.id,jsonb_build_object('customer_first_name',split_part(r.full_name,' ',1),'due_date',to_char(r.licence_expiry,'DD Mon YYYY')),p_as_of,auth.uid()); if nid is not null then n:=n+1; end if; end if;
   end loop;
 end loop;
 for r in select s.*,a.customer_id,c.full_name,v.registration,v.make,v.model from public.vehicle_maintenance_status s join public.vehicle_assignments a on a.vehicle_id=s.vehicle_id and a.assignment_status='ACTIVE' join public.customers c on c.id=a.customer_id join public.vehicles v on v.id=s.vehicle_id where s.status in ('DUE_SOON','OVERDUE') loop
   dtype:=case when r.status='OVERDUE' then 'SERVICE_OVERDUE' else 'SERVICE_DUE' end; nid:=app_private.queue_notification('service:'||r.vehicle_id||':'||r.status,dtype,r.customer_id,jsonb_build_object('customer_first_name',split_part(r.full_name,' ',1),'vehicle_registration',r.registration,'vehicle_make_model',r.make||' '||r.model,'service_kilometres_remaining',greatest(r.km_remaining,0)::text),p_as_of,auth.uid(),r.vehicle_id); if nid is not null then n:=n+1; end if;
 end loop;
 for r in select p.id,p.customer_id,p.vehicle_id,p.scheduled_at,c.full_name,v.registration from public.pickup_checklists p join public.customers c on c.id=p.customer_id join public.vehicles v on v.id=p.vehicle_id where p.status not in ('COMPLETED','CANCELLED') and p.scheduled_at between p_as_of and p_as_of+interval '24 hours' loop foreach stage in array (select pickup_hours from public.notification_settings where id) loop sched:=r.scheduled_at-make_interval(hours=>stage); nid:=app_private.queue_notification('pickup:'||r.id||':'||stage,'PICKUP_REMINDER',r.customer_id,jsonb_build_object('customer_first_name',split_part(r.full_name,' ',1),'vehicle_registration',r.registration,'scheduled_pickup_time',to_char(r.scheduled_at at time zone 'Australia/Melbourne','DD Mon YYYY HH12:MI AM')),sched,auth.uid(),r.vehicle_id); if nid is not null then n:=n+1; end if; end loop; end loop;
 for r in select q.id,a.customer_id,a.vehicle_id,q.scheduled_at,c.full_name,v.registration from public.return_checklists q join public.vehicle_assignments a on a.id=q.assignment_id join public.customers c on c.id=a.customer_id join public.vehicles v on v.id=a.vehicle_id where q.status not in ('COMPLETED','CANCELLED') and q.scheduled_at between p_as_of and p_as_of+interval '24 hours' loop foreach stage in array (select return_hours from public.notification_settings where id) loop sched:=r.scheduled_at-make_interval(hours=>stage); nid:=app_private.queue_notification('return:'||r.id||':'||stage,'RETURN_REMINDER',r.customer_id,jsonb_build_object('customer_first_name',split_part(r.full_name,' ',1),'vehicle_registration',r.registration,'scheduled_return_time',to_char(r.scheduled_at at time zone 'Australia/Melbourne','DD Mon YYYY HH12:MI AM')),sched,auth.uid(),r.vehicle_id); if nid is not null then n:=n+1; end if; end loop; end loop;
 return n;
end $$;

create or replace function public.queue_supported_notification(p_type text,p_customer_id uuid,p_vehicle_id uuid default null,p_agreement_id uuid default null,p_issue_id uuid default null,p_scheduled_for timestamptz default now()) returns uuid language plpgsql security definer set search_path='' as $$
declare c public.customers; v public.vehicles; i public.vehicle_issues; data jsonb; nid uuid; allowed text[];
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into c from public.customers where id=p_customer_id; if not found then raise exception 'customer not found'; end if; if p_vehicle_id is not null then select * into v from public.vehicles where id=p_vehicle_id; end if; if p_issue_id is not null then select * into i from public.vehicle_issues where id=p_issue_id and customer_id=p_customer_id; if not found then raise exception 'issue context mismatch'; end if; end if;
 if p_type not in ('ISSUE_CREATED','ISSUE_STATUS_UPDATE','PAYMENT_DUE','PAYMENT_OVERDUE','SERVICE_DUE','SERVICE_OVERDUE','LICENCE_EXPIRING','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER') then raise exception 'unsupported manual notification type'; end if;
 data:=jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'vehicle_registration',coalesce(v.registration,''),'vehicle_make_model',coalesce(v.make||' '||v.model,''),'amount','0.00','due_date',to_char(coalesce(c.licence_expiry,current_date),'DD Mon YYYY'),'service_kilometres_remaining','0','scheduled_pickup_time',to_char(p_scheduled_for at time zone 'Australia/Melbourne','DD Mon YYYY HH12:MI AM'),'scheduled_return_time',to_char(p_scheduled_for at time zone 'Australia/Melbourne','DD Mon YYYY HH12:MI AM'),'issue_status',coalesce(i.status,'updated'));
 select allowed_variables into allowed from public.notification_templates where template_key=p_type;
 select jsonb_object_agg(key,value) into data from jsonb_each(data) where key=any(allowed);
 nid:=app_private.queue_notification('manual:'||gen_random_uuid(),p_type,p_customer_id,data,p_scheduled_for,auth.uid(),p_vehicle_id,p_agreement_id,p_issue_id,true); return nid; end $$;

create or replace function public.claim_notifications(p_limit integer default 20,p_lease_seconds integer default 60) returns setof public.notifications language plpgsql security definer set search_path='' as $$
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; if p_limit not between 1 and 100 or p_lease_seconds not between 10 and 300 then raise exception 'invalid claim bounds'; end if;
 return query with c as (select id from public.notifications where ((status in ('QUEUED','SCHEDULED') and scheduled_for<=now()) or (status='SENDING' and claim_expires_at<now())) order by scheduled_for,created_at for update skip locked limit p_limit) update public.notifications n set status='SENDING',retry_count=n.retry_count+1,claim_token=gen_random_uuid(),claim_expires_at=now()+make_interval(secs=>p_lease_seconds) from c where n.id=c.id returning n.*; end $$;
create or replace function public.complete_notification(p_id uuid,p_claim_token uuid,p_outcome text,p_provider_message_id text default null,p_failure_reason text default null) returns public.notifications language plpgsql security definer set search_path='' as $$
declare n public.notifications; target text;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; select * into n from public.notifications where id=p_id and status='SENDING' and claim_token=p_claim_token and claim_expires_at>=now() for update; if not found then raise exception 'active notification claim not found'; end if;
 target:=case when p_outcome='SUCCESS' then 'SENT' when p_outcome='TEMPORARY_FAILURE' and n.retry_count<n.max_retries then 'QUEUED' when p_outcome in ('TEMPORARY_FAILURE','PERMANENT_FAILURE') then 'FAILED' else null end; if target is null then raise exception 'invalid provider outcome'; end if;
 update public.notifications set status=target,provider_message_id=case when target='SENT' then p_provider_message_id else provider_message_id end,sent_at=case when target='SENT' then now() else sent_at end,failed_at=case when target='FAILED' then now() else null end,scheduled_for=case when target='QUEUED' then now()+make_interval(secs=>least(3600,30*(2^greatest(retry_count-1,0)))) else scheduled_for end,failure_reason=case when target='SENT' then null else left(p_failure_reason,500) end,claim_token=null,claim_expires_at=null where id=p_id returning * into n;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTIFICATION_STATUS_CHANGED','notification',n.id,jsonb_build_object('status',n.status,'retry_count',n.retry_count));
 if n.status='FAILED' then perform app_private.upsert_exception('MESSAGE_REPEATED_FAILURE','HIGH','message_delivery',n.id,'notification-failure:'||n.id,'Notification repeatedly failed',jsonb_build_object('notification_id',n.id,'type',n.type,'retry_count',n.retry_count),true,auth.uid()); end if; return n; end $$;
create or replace function public.retry_notification(p_id uuid) returns public.notifications language plpgsql security definer set search_path='' as $$ declare n public.notifications; begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; update public.notifications set status='QUEUED',retry_count=0,scheduled_for=now(),failed_at=null,failure_reason=null where id=p_id and status='FAILED' returning * into n; if not found then raise exception 'failed notification not found'; end if; insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTIFICATION_RETRIED','notification',n.id,'{}'); return n; end $$;
create or replace function public.cancel_notification(p_id uuid) returns public.notifications language plpgsql security definer set search_path='' as $$ declare n public.notifications; begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if; update public.notifications set status='CANCELLED',claim_token=null,claim_expires_at=null where id=p_id and status in ('QUEUED','SCHEDULED') returning * into n; if not found then raise exception 'queued notification not found'; end if; insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTIFICATION_CANCELLED','notification',n.id,'{}'); return n; end $$;

revoke all on function app_private.render_notification(text,jsonb,text[]),app_private.queue_notification(text,text,uuid,jsonb,timestamptz,uuid,uuid,uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.generate_notifications(timestamptz),public.queue_supported_notification(text,uuid,uuid,uuid,uuid,timestamptz),public.claim_notifications(integer,integer),public.complete_notification(uuid,uuid,text,text,text),public.retry_notification(uuid),public.cancel_notification(uuid) from public;
grant execute on function public.generate_notifications(timestamptz),public.queue_supported_notification(text,uuid,uuid,uuid,uuid,timestamptz),public.claim_notifications(integer,integer),public.complete_notification(uuid,uuid,text,text,text),public.retry_notification(uuid),public.cancel_notification(uuid) to authenticated;
