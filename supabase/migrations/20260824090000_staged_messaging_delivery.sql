-- Provider-independent staged messaging. Only the synthetic FAKE provider is enabled.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED',
  'CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED',
  'AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED',
  'PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED',
  'AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED',
  'EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED',
  'CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED',
  'RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED',
  'VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED',
  'NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN',
  'MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED',
  'MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY'
));

alter table public.operational_exceptions drop constraint operational_exceptions_exception_type_check;
alter table public.operational_exceptions add constraint operational_exceptions_exception_type_check check (exception_type in (
  'OVERDUE_CUSTOMER','HIGH_OUTSTANDING_BALANCE','AGREEMENT_AWAITING_SIGNATURE','UNALLOCATED_FUNDS',
  'PAYMENT_ALLOCATION','SCHEDULE_EXTENSION_FAILURE','VEHICLE_SWAP_FAILURE','VEHICLE_STATE_INCONSISTENCY',
  'CUSTOMER_APPROVAL','PICKUP_PREREQUISITE','RETURN_PREREQUISITE','LICENCE_EXPIRY','REGISTRATION_EXPIRY',
  'RWC_EXPIRY','SERVICE_DUE','SERVICE_OVERDUE','VEHICLE_OFF_ROAD_TOO_LONG','UNMATCHED_TOLL_FINE',
  'AMBIGUOUS_TOLL_FINE','DISPUTED_NOTICE','BROKEN_PAYMENT_PROMISE','OVERDUE_PAYMENT_ESCALATION',
  'REMINDER_WORKFLOW_FAILURE','MESSAGE_MISSING_CONTACT','MESSAGE_INVALID_CONTACT','MESSAGE_REPEATED_FAILURE','MESSAGE_STUCK_QUEUE'
));

create table public.message_templates (
  template_key text primary key check (template_key in (
    'PAYMENT_OVERDUE_FIRST','PAYMENT_OVERDUE_SECOND','PAYMENT_ESCALATION','SERVICE_DUE',
    'LICENCE_EXPIRING','REGO_EXPIRING','RWC_EXPIRING','MISSING_DOCUMENT','PICKUP_REMINDER','RETURN_REMINDER'
  )),
  channel text not null check (channel in ('SMS','EMAIL')),
  subject_template text,
  body_template text not null check (btrim(body_template) <> ''),
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint email_subject_required check (channel <> 'EMAIL' or btrim(coalesce(subject_template,'')) <> '')
);
create trigger message_templates_touch before update on public.message_templates for each row execute function app_private.touch_updated_at();

insert into public.message_templates(template_key,channel,subject_template,body_template) values
 ('PAYMENT_OVERDUE_FIRST','SMS',null,'Hi {{customer_name}}, your Veera payment of ${{amount}} is overdue. Please contact our team if you need help.'),
 ('PAYMENT_OVERDUE_SECOND','SMS',null,'Hi {{customer_name}}, a second reminder that ${{amount}} remains overdue. Please contact Veera today.'),
 ('PAYMENT_ESCALATION','EMAIL','Action required: overdue Veera payment','Hi {{customer_name}}, your overdue balance is ${{amount}}. Please contact Veera to resolve this account matter.'),
 ('SERVICE_DUE','SMS',null,'Hi {{customer_name}}, vehicle {{registration}} is due for service. Please contact Veera to arrange a booking.'),
 ('LICENCE_EXPIRING','EMAIL','Driver licence expiry reminder','Hi {{customer_name}}, your driver licence expires on {{due_date}}. Please provide an updated document.'),
 ('REGO_EXPIRING','EMAIL','Vehicle registration expiry reminder','Registration for {{registration}} expires on {{due_date}}. Please contact Veera.'),
 ('RWC_EXPIRING','EMAIL','Roadworthy certificate expiry reminder','The RWC for {{registration}} expires on {{due_date}}. Please contact Veera.'),
 ('MISSING_DOCUMENT','EMAIL','Document required','Hi {{customer_name}}, Veera still requires your {{document_type}} document.'),
 ('PICKUP_REMINDER','SMS',null,'Hi {{customer_name}}, this is a reminder about your upcoming pickup for {{registration}}.'),
 ('RETURN_REMINDER','SMS',null,'Hi {{customer_name}}, this is a reminder about the return of {{registration}}.');

create table public.customer_communication_preferences (
  customer_id uuid primary key references public.customers(id) on delete cascade,
  sms_opt_out boolean not null default false, email_opt_out boolean not null default false,
  suppression_reason text check (length(suppression_reason) <= 500),
  updated_by uuid not null references public.staff_profiles(user_id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint preference_reason_required check (not (sms_opt_out or email_opt_out) or btrim(coalesce(suppression_reason,'')) <> '')
);
create trigger customer_communication_preferences_touch before update on public.customer_communication_preferences for each row execute function app_private.touch_updated_at();

create table public.message_deliveries (
  id uuid primary key default gen_random_uuid(),
  logical_key text not null unique,
  reminder_action_id uuid unique references public.reminder_actions(id),
  customer_id uuid not null references public.customers(id), agreement_id uuid references public.agreements(id),
  vehicle_id uuid references public.vehicles(id), template_key text not null references public.message_templates(template_key),
  channel text not null check (channel in ('SMS','EMAIL','WHATSAPP')),
  provider text not null default 'FAKE' check (provider = 'FAKE'),
  recipient text, subject text, body text not null,
  template_data jsonb not null default '{}'::jsonb check (jsonb_typeof(template_data)='object'),
  status text not null default 'QUEUED' check (status in ('QUEUED','SENDING','SENT','DELIVERED','RETRY_WAIT','FAILED','CANCELLED','SUPPRESSED')),
  suppression_reason text check (length(suppression_reason)<=500),
  attempt_count integer not null default 0 check (attempt_count between 0 and 5), max_attempts integer not null default 3 check (max_attempts between 1 and 5),
  next_attempt_at timestamptz not null default now(), claimed_at timestamptz, claim_expires_at timestamptz,
  claim_token uuid, provider_message_id text, last_error_code text, last_error text check (length(last_error)<=500),
  sent_at timestamptz, delivered_at timestamptz, cancelled_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint message_terminal_state check (
    (status='SUPPRESSED' and btrim(coalesce(suppression_reason,''))<>'') or status<>'SUPPRESSED'
  )
);
create index message_delivery_queue on public.message_deliveries(status,next_attempt_at) where status in ('QUEUED','RETRY_WAIT','SENDING');
create index message_delivery_customer_history on public.message_deliveries(customer_id,created_at desc);
create trigger message_deliveries_touch before update on public.message_deliveries for each row execute function app_private.touch_updated_at();

alter table public.message_templates enable row level security;
alter table public.customer_communication_preferences enable row level security;
alter table public.message_deliveries enable row level security;
create policy staff_read_message_templates on public.message_templates for select to authenticated using(app_private.is_staff());
create policy staff_read_communication_preferences on public.customer_communication_preferences for select to authenticated using(app_private.is_staff());
create policy staff_read_message_deliveries on public.message_deliveries for select to authenticated using(app_private.is_staff());
revoke all on public.message_templates,public.customer_communication_preferences,public.message_deliveries from anon,authenticated;
grant select on public.message_templates,public.customer_communication_preferences,public.message_deliveries to authenticated;

create or replace function app_private.render_message(p_template text,p_data jsonb) returns text
language plpgsql immutable set search_path='' as $$ declare k text; v text; result text:=p_template;
begin for k,v in select key,value from jsonb_each_text(p_data) loop result:=replace(result,'{{'||k||'}}',v); end loop; return result; end $$;

create or replace function app_private.queue_message(
  p_logical_key text,p_customer_id uuid,p_template_key text,p_data jsonb,p_agreement_id uuid default null,
  p_vehicle_id uuid default null,p_reminder_action_id uuid default null,p_actor uuid default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare t public.message_templates; c public.customers; pref public.customer_communication_preferences; rid uuid; recipient text; reason text; contact_issue boolean:=false;
begin
 select * into t from public.message_templates where template_key=p_template_key and is_active;
 if not found then raise exception 'active message template not found'; end if;
 select * into c from public.customers where id=p_customer_id; if not found then raise exception 'customer not found'; end if;
 select * into pref from public.customer_communication_preferences where customer_id=c.id;
 recipient:=case t.channel when 'SMS' then nullif(btrim(c.phone),'') else nullif(btrim(c.email),'') end;
 if (t.channel='SMS' and coalesce(pref.sms_opt_out,false)) or (t.channel='EMAIL' and coalesce(pref.email_opt_out,false)) then reason:=coalesce(pref.suppression_reason,t.channel||' opt-out');
 elsif recipient is null then reason:='Missing '||lower(t.channel)||' contact'; contact_issue:=true;
 elsif (t.channel='SMS' and recipient !~ '^\+614[0-9]{8}$') or (t.channel='EMAIL' and recipient !~* '^[^@[:space:]]+@example\.(com|test)$') then reason:='Invalid or non-synthetic '||lower(t.channel)||' contact'; contact_issue:=true;
 end if;
 insert into public.message_deliveries(logical_key,reminder_action_id,customer_id,agreement_id,vehicle_id,template_key,channel,recipient,subject,body,template_data,status,suppression_reason)
 values(p_logical_key,p_reminder_action_id,p_customer_id,p_agreement_id,p_vehicle_id,p_template_key,t.channel,recipient,
   case when t.subject_template is null then null else app_private.render_message(t.subject_template,p_data) end,
   app_private.render_message(t.body_template,p_data),p_data,case when reason is null then 'QUEUED' else 'SUPPRESSED' end,reason)
 on conflict(logical_key) do nothing returning id into rid;
 if rid is not null and contact_issue then
   perform app_private.upsert_exception(case when recipient is null then 'MESSAGE_MISSING_CONTACT' else 'MESSAGE_INVALID_CONTACT' end,'HIGH','customer',p_customer_id,
    'message-contact:'||p_customer_id::text||':'||t.channel,reason,jsonb_build_object('delivery_id',rid,'channel',t.channel),false,p_actor);
 end if;
 return rid;
end $$;

create or replace function public.set_customer_communication_preferences(p_customer_id uuid,p_sms_opt_out boolean,p_email_opt_out boolean,p_reason text default null)
returns public.customer_communication_preferences language plpgsql security definer set search_path='' as $$ declare r public.customer_communication_preferences;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 insert into public.customer_communication_preferences(customer_id,sms_opt_out,email_opt_out,suppression_reason,updated_by)
 values(p_customer_id,coalesce(p_sms_opt_out,false),coalesce(p_email_opt_out,false),nullif(btrim(p_reason),''),auth.uid())
 on conflict(customer_id) do update set sms_opt_out=excluded.sms_opt_out,email_opt_out=excluded.email_opt_out,suppression_reason=excluded.suppression_reason,updated_by=excluded.updated_by
 returning * into r; return r; end $$;

create or replace function app_private.sync_payment_deliveries(p_as_of date,p_actor uuid) returns integer language plpgsql security definer set search_path='' as $$
declare r record; n int:=0; mid uuid; key text; template text;
begin
 update public.message_deliveries d set status='SUPPRESSED',suppression_reason='Active promise-to-pay',claim_token=null,claim_expires_at=null
 where d.reminder_action_id is not null and d.status in ('QUEUED','RETRY_WAIT','SENDING')
 and exists(select 1 from public.payment_promises p where p.agreement_id=d.agreement_id and p.status='ACTIVE' and p.promised_date>=p_as_of);
 update public.message_deliveries d set status='CANCELLED',cancelled_at=now(),claim_token=null,claim_expires_at=null,last_error='Payment cleared before delivery'
 where d.reminder_action_id is not null and d.status in ('QUEUED','RETRY_WAIT','SENDING')
 and not exists(select 1 from public.agreement_payment_summary s where s.agreement_id=d.agreement_id and s.overdue_amount>0);
 for r in select ra.*,c.full_name from public.reminder_actions ra join public.customers c on c.id=ra.customer_id
   where ra.status='QUEUED' and not exists(select 1 from public.payment_promises p where p.agreement_id=ra.agreement_id and p.status='ACTIVE' and p.promised_date>=p_as_of) loop
   template:=case r.stage when 'FIRST' then 'PAYMENT_OVERDUE_FIRST' when 'SECOND' then 'PAYMENT_OVERDUE_SECOND' else 'PAYMENT_ESCALATION' end;
   key:='payment-reminder:'||r.id::text;
   mid:=app_private.queue_message(key,r.customer_id,template,jsonb_build_object('customer_name',r.full_name,'amount',to_char(r.overdue_amount,'FM999999990.00')),r.agreement_id,null,r.id,p_actor);
   if mid is not null then n:=n+1; end if;
 end loop; return n; end $$;

create or replace function public.generate_message_reminders(p_as_of date default current_date) returns integer
language plpgsql security definer set search_path='' as $$ declare r record; n int:=0; mid uuid;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 perform app_private.sync_payment_deliveries(p_as_of,auth.uid());
 for r in
  select 'licence:'||d.id::text||':'||d.expiry_date logical_key,d.customer_id,null::uuid vehicle_id,'LICENCE_EXPIRING' template_key,jsonb_build_object('customer_name',c.full_name,'due_date',d.expiry_date) data
    from public.customer_documents d join public.customers c on c.id=d.customer_id where d.document_type='DRIVER_LICENCE' and d.expiry_date between p_as_of and p_as_of+30
  union all select 'missing-document:'||d.id::text,d.customer_id,null,'MISSING_DOCUMENT',jsonb_build_object('customer_name',c.full_name,'document_type',lower(replace(d.document_type,'_',' '))) from public.customer_documents d join public.customers c on c.id=d.customer_id where d.status in ('MISSING','REJECTED','EXPIRED')
  union all select 'service:'||v.vehicle_id::text,v.customer_id,v.vehicle_id,'SERVICE_DUE',jsonb_build_object('customer_name',c.full_name,'registration',ve.registration) from public.vehicle_maintenance_status s join public.vehicle_assignments v on v.vehicle_id=s.vehicle_id and v.assignment_status='ACTIVE' join public.customers c on c.id=v.customer_id join public.vehicles ve on ve.id=v.vehicle_id where s.status in ('DUE','OVERDUE')
  union all select lower(vc.compliance_type)||':'||vc.id::text||':'||vc.expires_at,v.customer_id,vc.vehicle_id,case vc.compliance_type when 'REGISTRATION' then 'REGO_EXPIRING' else 'RWC_EXPIRING' end,jsonb_build_object('customer_name',c.full_name,'registration',ve.registration,'due_date',vc.expires_at) from public.vehicle_compliance vc join public.vehicle_assignments v on v.vehicle_id=vc.vehicle_id and v.assignment_status='ACTIVE' join public.customers c on c.id=v.customer_id join public.vehicles ve on ve.id=vc.vehicle_id where vc.expires_at between p_as_of and p_as_of+30
  union all select 'pickup:'||p.id::text,p.customer_id,p.vehicle_id,'PICKUP_REMINDER',jsonb_build_object('customer_name',c.full_name,'registration',v.registration) from public.pickup_checklists p join public.customers c on c.id=p.customer_id join public.vehicles v on v.id=p.vehicle_id where p.status<>'COMPLETED'
  union all select 'return:'||rc.id::text,a.customer_id,a.vehicle_id,'RETURN_REMINDER',jsonb_build_object('customer_name',c.full_name,'registration',v.registration) from public.return_checklists rc join public.vehicle_assignments a on a.id=rc.assignment_id join public.customers c on c.id=a.customer_id join public.vehicles v on v.id=a.vehicle_id where rc.status<>'COMPLETED'
 loop mid:=app_private.queue_message(r.logical_key,r.customer_id,r.template_key,r.data,null,r.vehicle_id,null,auth.uid()); if mid is not null then n:=n+1; end if; end loop;
 return n; end $$;

create or replace function public.claim_message_deliveries(p_limit integer default 10,p_lease_seconds integer default 60)
returns setof public.message_deliveries language plpgsql security definer set search_path='' as $$
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_limit not between 1 and 100 or p_lease_seconds not between 10 and 300 then raise exception 'invalid claim bounds'; end if;
 perform app_private.sync_payment_deliveries(current_date,auth.uid());
 return query with candidates as (
   select d.id from public.message_deliveries d where ((d.status in ('QUEUED','RETRY_WAIT') and d.next_attempt_at<=now()) or (d.status='SENDING' and d.claim_expires_at<now()))
   order by d.next_attempt_at,d.created_at for update skip locked limit p_limit
 ) update public.message_deliveries d set status='SENDING',attempt_count=d.attempt_count+1,claimed_at=now(),claim_expires_at=now()+make_interval(secs=>p_lease_seconds),claim_token=gen_random_uuid()
 from candidates c where d.id=c.id returning d.*; end $$;

create or replace function public.complete_message_delivery(p_delivery_id uuid,p_claim_token uuid,p_outcome text,p_provider_message_id text default null,p_error_code text default null,p_error text default null)
returns public.message_deliveries language plpgsql security definer set search_path='' as $$ declare d public.message_deliveries; delay_seconds int;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 select * into d from public.message_deliveries where id=p_delivery_id and status='SENDING' and claim_token=p_claim_token and claim_expires_at>=now() for update;
 if not found then raise exception 'active delivery claim not found'; end if;
 if p_outcome='SUCCESS' then update public.message_deliveries set status='SENT',provider_message_id=p_provider_message_id,sent_at=now(),claim_token=null,claim_expires_at=null,last_error=null,last_error_code=null where id=d.id;
 elsif p_outcome='TEMPORARY_FAILURE' and d.attempt_count<d.max_attempts then delay_seconds:=least(3600,30*power(2,d.attempt_count-1)::int); update public.message_deliveries set status='RETRY_WAIT',next_attempt_at=now()+make_interval(secs=>delay_seconds),last_error_code=p_error_code,last_error=left(p_error,500),claim_token=null,claim_expires_at=null where id=d.id;
 elsif p_outcome in ('TEMPORARY_FAILURE','PERMANENT_FAILURE') then update public.message_deliveries set status='FAILED',last_error_code=p_error_code,last_error=left(p_error,500),claim_token=null,claim_expires_at=null where id=d.id;
 else raise exception 'invalid provider outcome'; end if;
 select * into d from public.message_deliveries where id=d.id;
 if d.status='FAILED' and d.attempt_count>=d.max_attempts then perform app_private.upsert_exception('MESSAGE_REPEATED_FAILURE','HIGH','message_delivery',d.id,'message-failure:'||d.id,d.last_error,jsonb_build_object('attempt_count',d.attempt_count,'error_code',d.last_error_code),true,auth.uid()); end if;
 return d; end $$;

create or replace function public.retry_message_delivery(p_delivery_id uuid) returns public.message_deliveries language plpgsql security definer set search_path='' as $$ declare d public.message_deliveries;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.message_deliveries set status='QUEUED',attempt_count=0,next_attempt_at=now(),claim_token=null,claim_expires_at=null,last_error=null,last_error_code=null
 where id=p_delivery_id and status='FAILED' and last_error_code in ('FAKE_TEMPORARY','TIMEOUT') returning * into d;
 if not found then raise exception 'delivery is not safely retryable'; end if; return d; end $$;

create or replace function public.cancel_message_delivery(p_delivery_id uuid) returns public.message_deliveries language plpgsql security definer set search_path='' as $$ declare d public.message_deliveries;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.message_deliveries set status='CANCELLED',cancelled_at=now(),claim_token=null,claim_expires_at=null where id=p_delivery_id and status in ('QUEUED','RETRY_WAIT') returning * into d;
 if not found then raise exception 'queued delivery not found'; end if; return d; end $$;

create or replace function public.refresh_message_delivery_exceptions(p_stuck_minutes integer default 10) returns integer language plpgsql security definer set search_path='' as $$ declare d record; n int:=0;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 for d in select * from public.message_deliveries where status='SENDING' and claim_expires_at<now()-make_interval(mins=>p_stuck_minutes) loop
  perform app_private.upsert_exception('MESSAGE_STUCK_QUEUE','HIGH','message_delivery',d.id,'message-stuck:'||d.id,'Message delivery has remained stuck beyond its lease',jsonb_build_object('claimed_at',d.claimed_at),true,auth.uid()); n:=n+1; end loop; return n; end $$;

-- Keep payment action generation and delivery creation in the same transaction.
create or replace function public.run_collection_workflows(p_as_of date default current_date) returns table(reminders_queued integer,promises_broken integer,exceptions_refreshed integer)
language plpgsql security definer set search_path='' as $$ declare x record; q int:=0; b int:=0; e int:=0; rid uuid;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 for x in select p.*,s.overdue_amount from public.payment_promises p join public.agreement_payment_summary s on s.agreement_id=p.agreement_id where p.status='ACTIVE' and p.promised_date<p_as_of and s.overdue_amount>0 for update of p loop update public.payment_promises set status='BROKEN' where id=x.id; b:=b+1; perform app_private.upsert_exception('BROKEN_PAYMENT_PROMISE','HIGH','agreement',x.agreement_id,'broken-promise:'||x.agreement_id,'Payment promise passed without clearing arrears',jsonb_build_object('promise_id',x.id),true,auth.uid()); e:=e+1; end loop;
 update public.reminder_actions r set status='CANCELLED' where r.status='QUEUED' and not exists(select 1 from public.agreement_payment_summary s where s.agreement_id=r.agreement_id and s.overdue_amount>0);
 for x in select a.id agreement_id,a.customer_id,s.overdue_amount,s.oldest_overdue_date,rr.stage,rr.owner_exception from public.agreements a join public.agreement_payment_summary s on s.agreement_id=a.id join public.reminder_rules rr on rr.enabled and rr.overdue_days<=p_as_of-s.oldest_overdue_date where a.status='ACTIVE' and s.overdue_amount>0 and (not rr.suppress_for_active_promise or not exists(select 1 from public.payment_promises p where p.agreement_id=a.id and p.status='ACTIVE' and p.promised_date>=p_as_of)) loop insert into public.reminder_actions(agreement_id,customer_id,stage,overdue_amount) values(x.agreement_id,x.customer_id,x.stage,x.overdue_amount) on conflict(agreement_id,stage) do nothing returning id into rid; if rid is not null then q:=q+1; end if; rid:=null; if x.owner_exception then perform app_private.upsert_exception('OVERDUE_PAYMENT_ESCALATION','HIGH','agreement',x.agreement_id,'collection-escalation:'||x.agreement_id,'Overdue agreement reached collection escalation threshold',jsonb_build_object('stage',x.stage),true,auth.uid()); e:=e+1; end if; end loop;
 perform app_private.sync_payment_deliveries(p_as_of,auth.uid()); return query select q,b,e; end $$;

revoke all on function public.set_customer_communication_preferences(uuid,boolean,boolean,text),public.generate_message_reminders(date),public.claim_message_deliveries(integer,integer),public.complete_message_delivery(uuid,uuid,text,text,text,text),public.retry_message_delivery(uuid),public.cancel_message_delivery(uuid),public.refresh_message_delivery_exceptions(integer) from public;
grant execute on function public.set_customer_communication_preferences(uuid,boolean,boolean,text),public.generate_message_reminders(date),public.claim_message_deliveries(integer,integer),public.complete_message_delivery(uuid,uuid,text,text,text,text),public.retry_message_delivery(uuid),public.cancel_message_delivery(uuid),public.refresh_message_delivery_exceptions(integer) to authenticated;
revoke all on function app_private.render_message(text,jsonb),app_private.queue_message(text,uuid,text,jsonb,uuid,uuid,uuid,uuid),app_private.sync_payment_deliveries(date,uuid) from public,anon,authenticated;
