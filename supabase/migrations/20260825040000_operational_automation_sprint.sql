-- Local/staging operational automation, notification completion, and staff-safe read models.
-- No production scheduler, provider, webhook, or credential is introduced.

alter table public.audit_events drop constraint audit_events_action_check;
alter table public.audit_events add constraint audit_events_action_check check (action in (
  'ASSIGNMENT_CREATED','VEHICLE_RETURNED','VEHICLE_SWAPPED','VEHICLE_STATUS_CHANGED','CUSTOMER_CREATED','CUSTOMER_EDITED','CUSTOMER_STATUS_CHANGED','VEHICLE_CREATED','VEHICLE_EDITED','STAFF_ACCESS_CHANGED','AGREEMENT_CREATED','AGREEMENT_ACTIVATED','AGREEMENT_SUSPENDED','AGREEMENT_COMPLETED','AGREEMENT_CANCELLED','PAYMENT_MANUALLY_RECORDED','PAYMENT_REVERSED','PAYMENT_ADJUSTED','SCHEDULE_GENERATED','AGREEMENT_VEHICLE_SWAPPED','SCHEDULE_EXTENSION_EXECUTED','SCHEDULE_EXTENSION_FAILED','EXCEPTION_CREATED','EXCEPTION_ASSIGNED','EXCEPTION_RESOLVED','CUSTOMER_APPROVED','CUSTOMER_REJECTED','CUSTOMER_SUSPENDED','DOCUMENT_VERIFIED','DOCUMENT_REJECTED','COMPLIANCE_UPDATED','PICKUP_COMPLETED','RETURN_COMPLETED','MAINTENANCE_JOB_OPENED','MAINTENANCE_JOB_COMPLETED','ODOMETER_RECORDED','VEHICLE_WORKSHOP_STATE_CHANGED','NOTICE_CREATED','NOTICE_AUTO_MATCHED','NOTICE_ALLOCATION_CHANGED','NOTICE_STATUS_CHANGED','COMMUNICATION_LOGGED','REMINDER_QUEUED','PROMISE_CREATED','PROMISE_CHANGED','PROMISE_BROKEN','MESSAGE_QUEUED','MESSAGE_CLAIMED','MESSAGE_SENT','MESSAGE_RETRY_SCHEDULED','MESSAGE_FAILED','MESSAGE_CANCELLED','MESSAGE_SUPPRESSED','MESSAGE_MANUAL_RETRY','BANK_IMPORT_BATCH_CREATED','BANK_TRANSACTION_IMPORTED','BANK_MATCH_GENERATED','BANK_AUTO_ALLOCATED','BANK_MANUAL_MATCH_OVERRIDE','BANK_TRANSACTION_ALLOCATED','BANK_TRANSACTION_IGNORED','BANK_RECONCILIATION_REVERSED','VEHICLE_ISSUE_CREATED','VEHICLE_ISSUE_ASSIGNED','VEHICLE_ISSUE_STATUS_CHANGED','VEHICLE_ISSUE_NOTE_ADDED','VEHICLE_ISSUE_RESOLVED','PICKUP_SCHEDULED','RETURN_SCHEDULED','MAINTENANCE_RECORD_CREATED','MAINTENANCE_RECORD_STATUS_CHANGED','MAINTENANCE_RECORD_COMPLETED','SERVICE_INTERVAL_CHANGED','COMPLIANCE_ATTENTION_REFRESHED','NOTIFICATION_CREATED','NOTIFICATION_CANCELLED','NOTIFICATION_RETRIED','NOTIFICATION_CLAIMED','NOTIFICATION_STATUS_CHANGED','NOTIFICATION_MANUALLY_QUEUED','CUSTOMER_PORTAL_ISSUE_SUBMITTED','CUSTOMER_PORTAL_RESCHEDULE_REQUESTED','CUSTOMER_PORTAL_PROFILE_CHANGE_REQUESTED','CUSTOMER_PORTAL_ACCESS_CHANGED','PORTAL_REQUEST_SUBMITTED','PORTAL_REQUEST_ASSIGNED','PORTAL_REQUEST_APPROVED','PORTAL_REQUEST_DECLINED','PORTAL_REQUEST_COMPLETED','DOCUMENT_UPLOADED','DOCUMENT_REPLACED','DOCUMENT_ACCESS_ISSUED','AGREEMENT_DOCUMENT_UPLOADED','TOLL_FINE_IMPORT','TOLL_FINE_MATCH','TOLL_FINE_CONFIRM','TOLL_FINE_OVERRIDE','TOLL_FINE_DISPUTE','TOLL_FINE_TRANSFER_PENDING','TOLL_FINE_TRANSFERRED','TOLL_FINE_CANCELLED',
  'SCHEDULED_JOB_STARTED','SCHEDULED_JOB_COMPLETED','SCHEDULED_JOB_FAILED','SCHEDULED_JOB_SETTING_CHANGED','NOTIFICATION_DELIVERY_RECORDED','NOTIFICATION_DELIVERED','NOTIFICATION_SETTINGS_CHANGED'
));

-- Notification settings are bounded configuration, never executable template code.
alter table public.notification_settings
  add column issue_status_auto_notify boolean not null default false,
  add column payment_pre_due_days integer[] not null default '{1}',
  add constraint notification_payment_stage_bounds check(payment_stages<@array[0,1,3,7,14,21]),
  add constraint notification_payment_pre_due_bounds check(payment_pre_due_days<@array[1,2,3,7,14]),
  add constraint notification_licence_stage_bounds check(licence_stages<@array[0,1,3,7,14,30,60]),
  add constraint notification_pickup_stage_bounds check(pickup_hours<@array[0,1,2,6,12,24,48,72]),
  add constraint notification_return_stage_bounds check(return_hours<@array[0,1,2,6,12,24,48,72]);
update public.notification_settings set payment_stages='{0,1,3,7}',payment_pre_due_days='{1}';

create table public.notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(), notification_id uuid not null references public.notifications(id),
  attempt_number integer not null check(attempt_number>0), provider text not null check(btrim(provider)<>'' and length(provider)<=80),
  attempted_at timestamptz not null default now(), result text not null check(result in ('SENT','TEMPORARY_FAILURE','PERMANENT_FAILURE')),
  provider_message_id text check(provider_message_id is null or length(provider_message_id)<=200),
  safe_error_category text check(safe_error_category is null or safe_error_category in ('TIMEOUT','RATE_LIMIT','INVALID_RECIPIENT','PROVIDER_UNAVAILABLE','REJECTED','UNKNOWN')),
  duration_ms integer check(duration_ms is null or duration_ms between 0 and 300000), created_at timestamptz not null default now(),
  unique(notification_id,attempt_number)
);
alter table public.notification_delivery_attempts enable row level security;
create policy staff_read_notification_attempts on public.notification_delivery_attempts for select to authenticated using(app_private.is_staff());
revoke all on public.notification_delivery_attempts from anon,authenticated;
grant select on public.notification_delivery_attempts to authenticated;
create or replace function app_private.immutable_operational_history() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'operational execution history is immutable'; end $$;
create trigger notification_delivery_attempts_immutable before update or delete on public.notification_delivery_attempts for each row execute function app_private.immutable_operational_history();

create or replace function public.complete_notification(p_id uuid,p_claim_token uuid,p_outcome text,p_provider_message_id text default null,p_failure_reason text default null,p_safe_error_category text default null,p_duration_ms integer default null,p_provider text default 'LOCAL') returns public.notifications language plpgsql security definer set search_path='' as $$
declare n public.notifications; target text; attempt_no integer;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_failure_reason is not null and length(p_failure_reason)>5000 then raise exception 'provider failure detail exceeds safe input bound'; end if;
 select * into n from public.notifications where id=p_id and status='SENDING' and claim_token=p_claim_token and claim_expires_at>=now() for update; if not found then raise exception 'active notification claim not found'; end if;
 target:=case when p_outcome='SUCCESS' then 'SENT' when p_outcome='TEMPORARY_FAILURE' and n.retry_count<n.max_retries then 'QUEUED' when p_outcome in ('TEMPORARY_FAILURE','PERMANENT_FAILURE') then 'FAILED' end; if target is null then raise exception 'invalid provider outcome'; end if;
 if p_safe_error_category is not null and p_safe_error_category not in ('TIMEOUT','RATE_LIMIT','INVALID_RECIPIENT','PROVIDER_UNAVAILABLE','REJECTED','UNKNOWN') then raise exception 'invalid safe error category'; end if;
 select coalesce(max(attempt_number),0)+1 into attempt_no from public.notification_delivery_attempts where notification_id=n.id;
 insert into public.notification_delivery_attempts(notification_id,attempt_number,provider,result,provider_message_id,safe_error_category,duration_ms)
 values(n.id,attempt_no,left(btrim(p_provider),80),case when p_outcome='SUCCESS' then 'SENT' else p_outcome end,case when p_outcome='SUCCESS' then left(p_provider_message_id,200) end,case when p_outcome<>'SUCCESS' then coalesce(p_safe_error_category,'UNKNOWN') end,p_duration_ms);
 update public.notifications set status=target,provider_message_id=case when target='SENT' then left(p_provider_message_id,200) else provider_message_id end,sent_at=case when target='SENT' then now() else sent_at end,failed_at=case when target='FAILED' then now() end,scheduled_for=case when target='QUEUED' then now()+make_interval(secs=>least(3600,30*(2^greatest(retry_count-1,0)))) else scheduled_for end,failure_reason=case when target='SENT' then null else left(coalesce(p_safe_error_category,'UNKNOWN'),500) end,claim_token=null,claim_expires_at=null where id=p_id returning * into n;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTIFICATION_DELIVERY_RECORDED','notification',n.id,jsonb_build_object('status',n.status,'attempt_number',attempt_no,'provider',p_provider,'safe_error_category',p_safe_error_category));
 if n.status='FAILED' then perform app_private.upsert_exception('MESSAGE_REPEATED_FAILURE','HIGH','notification',n.id,'notification-failure:'||n.id,'Important notification repeatedly failed',jsonb_build_object('notification_id',n.id,'type',n.type,'retry_count',n.retry_count),true,auth.uid()); end if;
 return n;
end $$;

create or replace function public.record_notification_delivery_receipt(p_notification_id uuid,p_provider_message_id text) returns public.notifications language plpgsql security definer set search_path='' as $$
declare n public.notifications;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.notifications set status='DELIVERED',delivered_at=now() where id=p_notification_id and status='SENT' and provider_message_id=p_provider_message_id returning * into n; if not found then raise exception 'matching sent notification not found'; end if;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTIFICATION_DELIVERED','notification',n.id,jsonb_build_object('provider_message_id',left(p_provider_message_id,200))); return n; end $$;

create or replace function app_private.queue_payment_received_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare a public.agreements; c public.customers;
begin
 if new.transaction_type='RECEIPT' and new.amount>0 then select * into a from public.agreements where id=new.agreement_id; select * into c from public.customers where id=a.customer_id;
   perform app_private.queue_notification('payment-received:'||new.id,'PAYMENT_RECEIVED',a.customer_id,jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'amount',to_char(new.amount,'FM999999990.00')),now(),new.created_by,a.vehicle_id,a.id);
 end if; return new; end $$;
create trigger payment_received_notification after insert on public.payment_transactions for each row execute function app_private.queue_payment_received_notification();

create or replace function public.generate_pre_due_payment_notifications(p_as_of timestamptz default now()) returns integer language plpgsql security definer set search_path='' as $$
declare payment record;days_before integer;notification_id uuid;total integer:=0;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;
 for payment in select s.*,a.customer_id,a.vehicle_id,c.full_name from public.payment_schedule_items s join public.agreements a on a.id=s.agreement_id and a.status='ACTIVE' join public.customers c on c.id=a.customer_id where s.status not in ('PAID','WAIVED') loop
  foreach days_before in array(select payment_pre_due_days from public.notification_settings where id) loop
   if (p_as_of at time zone 'Australia/Melbourne')::date>=payment.due_date-days_before and (p_as_of at time zone 'Australia/Melbourne')::date<payment.due_date then
    notification_id:=app_private.queue_notification('payment-pre-due:'||payment.id||':'||days_before,'PAYMENT_DUE',payment.customer_id,jsonb_build_object('customer_first_name',split_part(payment.full_name,' ',1),'amount',to_char(payment.amount_due-payment.amount_paid,'FM999999990.00'),'due_date',to_char(payment.due_date,'DD Mon YYYY')),(payment.due_date-days_before)::timestamp at time zone 'Australia/Melbourne',auth.uid(),payment.vehicle_id,payment.agreement_id);if notification_id is not null then total:=total+1;end if;
   end if;
  end loop;
 end loop;return total;end $$;

create or replace function public.update_notification_settings(p_payment_stages integer[],p_pre_due_days integer[],p_pickup_hours integer[],p_return_hours integer[],p_licence_stages integer[],p_max_retries integer,p_issue_auto_notify boolean) returns public.notification_settings language plpgsql security definer set search_path='' as $$
declare s public.notification_settings;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 if p_max_retries not between 1 and 5 or cardinality(p_payment_stages) not between 1 and 10 or cardinality(p_pre_due_days) not between 1 and 5 or cardinality(p_pickup_hours) not between 1 and 8 or cardinality(p_return_hours) not between 1 and 8 or cardinality(p_licence_stages) not between 1 and 8 then raise exception 'settings outside supported bounds'; end if;
 update public.notification_settings set payment_stages=(select array_agg(distinct x order by x) from unnest(p_payment_stages)x),payment_pre_due_days=(select array_agg(distinct x order by x) from unnest(p_pre_due_days)x),pickup_hours=(select array_agg(distinct x order by x desc) from unnest(p_pickup_hours)x),return_hours=(select array_agg(distinct x order by x desc) from unnest(p_return_hours)x),licence_stages=(select array_agg(distinct x order by x desc) from unnest(p_licence_stages)x),max_retries=p_max_retries,issue_status_auto_notify=p_issue_auto_notify,updated_by=auth.uid(),updated_at=now() where id returning * into s;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'NOTIFICATION_SETTINGS_CHANGED','notification_settings',auth.uid(),jsonb_build_object('payment_stages',s.payment_stages,'max_retries',s.max_retries,'issue_auto_notify',s.issue_status_auto_notify)); return s; end $$;

create or replace function app_private.queue_issue_status_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare i public.vehicle_issues; c public.customers; v public.vehicles; actor_id uuid;
begin
 if new.event_type in ('STATUS_CHANGED','RESOLVED') and (select issue_status_auto_notify from public.notification_settings where id) then select * into i from public.vehicle_issues where id=new.vehicle_issue_id; if i.customer_id is not null then select * into c from public.customers where id=i.customer_id; select * into v from public.vehicles where id=i.vehicle_id; actor_id:=coalesce(new.actor,i.created_by);
   perform app_private.queue_notification('issue-status:'||new.id,'ISSUE_STATUS_UPDATE',i.customer_id,jsonb_build_object('customer_first_name',split_part(c.full_name,' ',1),'vehicle_registration',v.registration,'issue_status',replace(lower(new.to_status),'_',' ')),now(),actor_id,i.vehicle_id,i.agreement_id,i.id);
 end if; end if; return new; end $$;
create trigger vehicle_issue_status_notification after insert on public.vehicle_issue_events for each row execute function app_private.queue_issue_status_notification();

create or replace function public.refresh_notification_attention() returns integer language plpgsql security definer set search_path='' as $$
declare notification_record public.notifications; total integer:=0;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;
 update public.operational_exceptions e set status='RESOLVED',resolved_at=now(),resolution_note='Communication condition cleared',updated_at=now() where e.status<>'RESOLVED' and e.exception_type='MISSING_IMPORTANT_CUSTOMER_CONTACT' and not exists(select 1 from public.notifications current_notification where current_notification.customer_id=e.entity_id and current_notification.status='SUPPRESSED' and current_notification.failure_reason='Missing customer contact' and current_notification.type in ('PAYMENT_OVERDUE','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_STATUS_UPDATE') and current_notification.created_at>now()-interval '30 days');
 for notification_record in select distinct on (customer_id) * from public.notifications where status='SUPPRESSED' and failure_reason='Missing customer contact' and type in ('PAYMENT_OVERDUE','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_STATUS_UPDATE') and created_at>now()-interval '30 days' order by customer_id,created_at desc loop
   perform app_private.upsert_exception('MISSING_IMPORTANT_CUSTOMER_CONTACT','HIGH','customer',notification_record.customer_id,'missing-important-contact:'||notification_record.customer_id,'Missing customer contact blocks important communication',jsonb_build_object('notification_type',notification_record.type),true,auth.uid()); total:=total+1;
 end loop; return total; end $$;

-- Durable local/staging job registry and immutable execution ledger.
create table public.scheduled_jobs (
  job_key text primary key check(job_key in ('GENERATE_NOTIFICATIONS','PROCESS_LOCAL_NOTIFICATIONS','REFRESH_READINESS','REFRESH_OWNER','REFRESH_PORTAL_AGING','REFRESH_TOLL_FINE_ATTENTION','REFRESH_NOTIFICATION_ATTENTION','REFRESH_COLLECTIONS')),
  description text not null, enabled boolean not null default true, cadence_minutes integer not null check(cadence_minutes between 5 and 10080),
  config jsonb not null default '{}'::jsonb check(jsonb_typeof(config)='object'),last_started_at timestamptz,last_completed_at timestamptz,
  last_status text check(last_status in ('RUNNING','SUCCEEDED','FAILED','SKIPPED')),next_run_at timestamptz not null default now(),consecutive_failures integer not null default 0,
  locked_at timestamptz,lock_token uuid,updated_by uuid references public.staff_profiles(user_id),updated_at timestamptz not null default now()
);
insert into public.scheduled_jobs(job_key,description,cadence_minutes) values
('GENERATE_NOTIFICATIONS','Generate payment, pickup, return, licence, and maintenance reminders',60),
('PROCESS_LOCAL_NOTIFICATIONS','Process queued notifications with the synthetic local provider',15),
('REFRESH_READINESS','Refresh maintenance, compliance, and document exceptions',360),
('REFRESH_OWNER','Refresh payment and general owner attention',360),
('REFRESH_PORTAL_AGING','Refresh portal request and document aging',360),
('REFRESH_TOLL_FINE_ATTENTION','Refresh toll/fine owner exceptions',60),
('REFRESH_NOTIFICATION_ATTENTION','Refresh important delivery and missing-contact attention',60),
('REFRESH_COLLECTIONS','Refresh overdue payments and collection reminders',1440);
create table public.scheduled_job_executions (
  id uuid primary key default gen_random_uuid(),job_key text not null references public.scheduled_jobs(job_key),started_at timestamptz not null default now(),completed_at timestamptz,
  status text not null check(status in ('RUNNING','SUCCEEDED','FAILED','SKIPPED')),duration_ms integer check(duration_ms is null or duration_ms>=0),
  error_summary text check(error_summary is null or length(error_summary)<=500),result_summary jsonb not null default '{}'::jsonb check(jsonb_typeof(result_summary)='object'),
  trigger_source text not null check(trigger_source in ('DUE_RUNNER','MANUAL')),triggered_by uuid not null references public.staff_profiles(user_id),idempotency_key text not null unique,created_at timestamptz not null default now()
);
create unique index scheduled_job_one_running on public.scheduled_job_executions(job_key) where status='RUNNING';
alter table public.scheduled_jobs enable row level security;alter table public.scheduled_job_executions enable row level security;
create policy staff_read_scheduled_jobs on public.scheduled_jobs for select to authenticated using(app_private.is_staff());
create policy staff_read_job_executions on public.scheduled_job_executions for select to authenticated using(app_private.is_staff());
revoke all on public.scheduled_jobs,public.scheduled_job_executions from anon,authenticated;grant select on public.scheduled_jobs,public.scheduled_job_executions to authenticated;
create or replace function app_private.protect_job_execution_history() returns trigger language plpgsql set search_path='' as $$
begin if tg_op='DELETE' or old.status<>'RUNNING' or new.status not in ('SUCCEEDED','FAILED','SKIPPED') or new.job_key is distinct from old.job_key or new.started_at is distinct from old.started_at or new.trigger_source is distinct from old.trigger_source or new.triggered_by is distinct from old.triggered_by or new.idempotency_key is distinct from old.idempotency_key then raise exception 'completed job execution history is immutable';end if;return new;end $$;
create trigger scheduled_job_executions_immutable before update or delete on public.scheduled_job_executions for each row execute function app_private.protect_job_execution_history();

create or replace function app_private.execute_known_job(p_job_key text,p_actor uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb:=jsonb_build_object('actor',p_actor); claimed public.notifications;
begin
 case p_job_key
  when 'GENERATE_NOTIFICATIONS' then result:=jsonb_build_object('generated',public.generate_notifications(now()),'pre_due',public.generate_pre_due_payment_notifications(now()));
  when 'PROCESS_LOCAL_NOTIFICATIONS' then
   result:=jsonb_build_object('processed',0);
   for claimed in select * from public.claim_notifications(25,60) loop perform public.complete_notification(claimed.id,claimed.claim_token,'SUCCESS','local-'||claimed.id,null,null,0,'LOCAL_SYNTHETIC'); result:=jsonb_set(result,'{processed}',to_jsonb((result->>'processed')::integer+1)); end loop;
  when 'REFRESH_READINESS' then result:=jsonb_build_object('exceptions',public.refresh_readiness_exceptions(30,7),'maintenance',public.refresh_maintenance_compliance_attention());
  when 'REFRESH_OWNER' then perform public.refresh_owner_exceptions(14,2000); result:=jsonb_build_object('refreshed',true);
  when 'REFRESH_PORTAL_AGING' then result:=jsonb_build_object('exceptions',public.refresh_portal_exchange_exceptions());
  when 'REFRESH_TOLL_FINE_ATTENTION' then result:=jsonb_build_object('exceptions',public.refresh_toll_fine_owner_attention());
  when 'REFRESH_NOTIFICATION_ATTENTION' then result:=jsonb_build_object('exceptions',public.refresh_notification_attention());
  when 'REFRESH_COLLECTIONS' then perform public.run_collection_workflows(current_date); result:=jsonb_build_object('refreshed',true);
  else raise exception 'unsupported scheduled job'; end case; return result;
end $$;

create or replace function public.run_scheduled_job(p_job_key text,p_trigger_source text default 'MANUAL',p_idempotency_key text default null) returns public.scheduled_job_executions language plpgsql security definer set search_path='' as $$
declare j public.scheduled_jobs;e public.scheduled_job_executions;token uuid:=gen_random_uuid();started timestamptz:=clock_timestamp();result jsonb;key text;
begin
 if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501'; end if;if p_trigger_source not in ('DUE_RUNNER','MANUAL') then raise exception 'invalid trigger source';end if;
 key:=coalesce(nullif(btrim(p_idempotency_key),''),p_trigger_source||':'||p_job_key||':'||to_char(date_trunc('minute',now()),'YYYYMMDDHH24MI'));
 select * into e from public.scheduled_job_executions where idempotency_key=key;if found then return e;end if;
 update public.scheduled_jobs set locked_at=now(),lock_token=token,last_started_at=now(),last_status='RUNNING' where job_key=p_job_key and enabled and (locked_at is null or locked_at<now()-interval '10 minutes') returning * into j;
 if not found then raise exception 'job disabled, missing, or already running' using errcode='55000';end if;
 insert into public.scheduled_job_executions(job_key,status,trigger_source,triggered_by,idempotency_key) values(j.job_key,'RUNNING',p_trigger_source,auth.uid(),key) returning * into e;
 insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'SCHEDULED_JOB_STARTED','scheduled_job_execution',e.id,jsonb_build_object('job_key',j.job_key,'trigger_source',p_trigger_source));
 begin
   result:=app_private.execute_known_job(j.job_key,auth.uid());
   update public.scheduled_job_executions set status='SUCCEEDED',completed_at=clock_timestamp(),duration_ms=extract(epoch from clock_timestamp()-started)*1000,result_summary=result where id=e.id returning * into e;
   update public.scheduled_jobs set last_completed_at=e.completed_at,last_status='SUCCEEDED',next_run_at=e.completed_at+make_interval(mins=>cadence_minutes),consecutive_failures=0,locked_at=null,lock_token=null where job_key=j.job_key;
   insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'SCHEDULED_JOB_COMPLETED','scheduled_job_execution',e.id,jsonb_build_object('job_key',j.job_key,'duration_ms',e.duration_ms));
 exception when others then
   update public.scheduled_job_executions set status='FAILED',completed_at=clock_timestamp(),duration_ms=extract(epoch from clock_timestamp()-started)*1000,error_summary=left(sqlerrm,500) where id=e.id returning * into e;
   update public.scheduled_jobs set last_completed_at=e.completed_at,last_status='FAILED',next_run_at=now()+interval '15 minutes',consecutive_failures=consecutive_failures+1,locked_at=null,lock_token=null where job_key=j.job_key;
   if (select consecutive_failures>=3 from public.scheduled_jobs where job_key=j.job_key) then perform app_private.upsert_exception('AUTOMATION_JOB_REPEATED_FAILURE','HIGH','scheduled_job_execution',e.id,'automation-job:'||j.job_key,'Automation job repeatedly failed',jsonb_build_object('job_key',j.job_key),true,auth.uid());end if;
   insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'SCHEDULED_JOB_FAILED','scheduled_job_execution',e.id,jsonb_build_object('job_key',j.job_key,'error',e.error_summary));
 end;return e;
end $$;

create or replace function public.run_due_scheduled_jobs(p_limit integer default 8) returns setof public.scheduled_job_executions language plpgsql security definer set search_path='' as $$
declare j record;e public.scheduled_job_executions;
begin if not app_private.is_staff() then raise exception 'staff access required' using errcode='42501';end if;if p_limit not between 1 and 20 then raise exception 'invalid job limit';end if;
 for j in select job_key from public.scheduled_jobs where enabled and next_run_at<=now() and (locked_at is null or locked_at<now()-interval '10 minutes') order by next_run_at for update skip locked limit p_limit loop begin e:=public.run_scheduled_job(j.job_key,'DUE_RUNNER','due:'||j.job_key||':'||to_char(date_trunc('minute',now()),'YYYYMMDDHH24MI'));return next e;exception when others then continue;end;end loop;return;end $$;

create or replace function public.set_scheduled_job_enabled(p_job_key text,p_enabled boolean) returns public.scheduled_jobs language plpgsql security definer set search_path='' as $$
declare j public.scheduled_jobs;begin if not app_private.is_admin() then raise exception 'admin access required' using errcode='42501';end if;update public.scheduled_jobs set enabled=p_enabled,next_run_at=case when p_enabled then least(next_run_at,now()) else next_run_at end,updated_by=auth.uid(),updated_at=now() where job_key=p_job_key and lock_token is null returning * into j;if not found then raise exception 'unlocked scheduled job not found';end if;insert into public.audit_events(actor,action,entity_type,entity_id,metadata) values(auth.uid(),'SCHEDULED_JOB_SETTING_CHANGED','scheduled_job',auth.uid(),jsonb_build_object('job_key',p_job_key,'enabled',p_enabled));return j;end $$;

-- Staff-safe operational projections. Contact details, addresses, raw bank fields, and document paths are excluded.
create or replace view public.customer_operational_summary with (security_invoker=true) as
select c.id customer_id,c.full_name,c.status,a.id agreement_id,a.status agreement_status,v.id vehicle_id,v.registration,v.make,v.model,a.weekly_amount,
 coalesce(ps.overdue_amount,0) overdue_amount,case when coalesce(ps.overdue_amount,0)>0 then 'OVERDUE' when a.id is not null then 'CURRENT' else 'NO_ACTIVE_AGREEMENT' end payment_state,
 case when c.licence_expiry is null then 'MISSING' when c.licence_expiry<current_date then 'EXPIRED' when c.licence_expiry<=current_date+30 then 'EXPIRING' else 'VALID' end licence_state,
 (exists(select 1 from public.customer_documents d where d.customer_id=c.id and d.document_type='DRIVER_LICENCE' and d.status='VERIFIED') and exists(select 1 from public.customer_documents d where d.customer_id=c.id and d.document_type='PROOF_OF_ADDRESS' and d.status='VERIFIED')) document_complete,
 (select count(*) from public.vehicle_issues i where i.customer_id=c.id and i.status not in ('RESOLVED','CANCELLED')) open_issue_count,
 exists(select 1 from public.customer_portal_accounts p where p.customer_id=c.id and p.status='ACTIVE') portal_enabled,
 (select count(*) from public.customer_portal_requests r where r.customer_id=c.id and r.status in ('SUBMITTED','IN_REVIEW')) pending_portal_request_count
from public.customers c left join lateral(select * from public.agreements x where x.customer_id=c.id and x.status in ('ACTIVE','PENDING_SIGNATURE') order by (x.status='ACTIVE') desc,x.created_at desc limit 1)a on true left join public.vehicles v on v.id=a.vehicle_id left join public.agreement_payment_summary ps on ps.agreement_id=a.id;

create or replace view public.vehicle_operational_detail with (security_invoker=true) as
select v.id vehicle_id,v.registration,v.make,v.model,v.odometer,v.operational_status,a.id assignment_id,a.customer_id,c.full_name customer_name,g.id agreement_id,g.weekly_amount,
 p.scheduled_at pickup_scheduled_at,p.actual_at pickup_actual_at,r.scheduled_at return_scheduled_at,r.actual_at return_actual_at,
 (v.operational_status='AVAILABLE' and app_private.vehicle_is_compliant(v.id) and ms.status not in ('OVERDUE','IN_PROGRESS') and not app_private.vehicle_has_blocking_issue(v.id)) readiness,ms.status maintenance_status,
 coalesce((select exposure from public.vehicle_compliance_exposure where vehicle_id=v.id and compliance_type='REGISTRATION'),'MISSING') registration_status,
 coalesce((select exposure from public.vehicle_compliance_exposure where vehicle_id=v.id and compliance_type='RWC'),'MISSING') rwc_status,
 (select count(*) from public.vehicle_issues i where i.vehicle_id=v.id and i.status not in ('RESOLVED','CANCELLED')) open_issue_count,
 coalesce((select jsonb_agg(reason order by reason) from (select case when v.operational_status='WORKSHOP' then 'Vehicle is in workshop' end reason union all select case when not exists(select 1 from public.vehicle_compliance vc where vc.vehicle_id=v.id and vc.compliance_type='REGISTRATION' and vc.status in ('VALID','EXPIRING_SOON') and vc.expires_at>=current_date) then 'Registration is not valid' end union all select case when not exists(select 1 from public.vehicle_compliance vc where vc.vehicle_id=v.id and vc.compliance_type='RWC' and vc.status in ('VALID','EXPIRING_SOON') and vc.expires_at>=current_date) then 'RWC is not valid' end union all select case when ms.status='OVERDUE' then 'Service is overdue' end union all select case when app_private.vehicle_has_blocking_issue(v.id) then 'Vehicle has a blocking issue' end)q where reason is not null),'[]'::jsonb) readiness_blockers,
 coalesce(ps.overdue_amount,0) agreement_overdue_amount
from public.vehicles v left join public.vehicle_maintenance_status ms on ms.vehicle_id=v.id left join lateral(select * from public.vehicle_assignments x where x.vehicle_id=v.id and x.assignment_status='ACTIVE' order by assigned_at desc limit 1)a on true left join public.customers c on c.id=a.customer_id left join lateral(select * from public.agreements x where x.vehicle_id=v.id and x.customer_id=a.customer_id and x.status in ('ACTIVE','SUSPENDED') order by created_at desc limit 1)g on true left join lateral(select * from public.pickup_checklists x where x.vehicle_id=v.id order by created_at desc limit 1)p on true left join lateral(select * from public.return_checklists x where x.assignment_id=a.id order by created_at desc limit 1)r on true left join public.agreement_payment_summary ps on ps.agreement_id=g.id;

create or replace view public.movement_readiness with (security_invoker=true) as
select v.vehicle_id,v.registration,v.readiness,
 coalesce(v.readiness_blockers,'[]'::jsonb)||case when cr.customer_id is not null and not cr.ready then jsonb_build_array('Customer approval or required documents are incomplete') else '[]'::jsonb end blockers
from public.vehicle_operational_detail v left join public.customer_readiness cr on cr.customer_id=v.customer_id;

create or replace view public.issue_work_queue with (security_invoker=true) as
select i.id,i.vehicle_id,v.registration,i.customer_id,c.full_name customer_name,i.assigned_to,s.full_name assigned_staff_name,i.severity,i.category,i.status,i.created_at,i.updated_at,
 case when i.status='RESOLVED' then 'RESOLVED' when i.assigned_to=auth.uid() then 'ASSIGNED_TO_ME' when i.severity='CRITICAL' then 'CRITICAL' when i.status in ('WAITING_CUSTOMER','WAITING_PARTS') then 'WAITING' else 'OPEN' end queue_group
from public.vehicle_issues i join public.vehicles v on v.id=i.vehicle_id left join public.customers c on c.id=i.customer_id left join public.staff_profiles s on s.user_id=i.assigned_to where app_private.is_staff();

create or replace view public.notification_attention with (security_invoker=true) as
select n.id,n.customer_id,c.full_name customer_name,n.type,n.channel,n.status,n.retry_count,n.max_retries,n.failure_reason,n.scheduled_for,n.created_at,
 case when n.status='FAILED' and n.retry_count>=n.max_retries then 'REPEATED_FAILURE' when n.status='FAILED' then 'RETRY_REQUIRED' when n.status='SUPPRESSED' then 'IMPORTANT_SUPPRESSED' else 'NEEDS_ATTENTION' end attention_reason
from public.notifications n left join public.customers c on c.id=n.customer_id where n.status='FAILED' or (n.status='SUPPRESSED' and n.type in ('PAYMENT_OVERDUE','LICENCE_EXPIRED','PICKUP_REMINDER','RETURN_REMINDER','ISSUE_STATUS_UPDATE'));

grant select on public.customer_operational_summary,public.vehicle_operational_detail,public.movement_readiness,public.issue_work_queue,public.notification_attention to authenticated;

revoke all on function public.complete_notification(uuid,uuid,text,text,text,text,integer,text),public.record_notification_delivery_receipt(uuid,text),public.generate_pre_due_payment_notifications(timestamptz),public.update_notification_settings(integer[],integer[],integer[],integer[],integer[],integer,boolean),public.refresh_notification_attention(),public.run_scheduled_job(text,text,text),public.run_due_scheduled_jobs(integer),public.set_scheduled_job_enabled(text,boolean) from public;
grant execute on function public.complete_notification(uuid,uuid,text,text,text,text,integer,text),public.record_notification_delivery_receipt(uuid,text),public.generate_pre_due_payment_notifications(timestamptz),public.update_notification_settings(integer[],integer[],integer[],integer[],integer[],integer,boolean),public.refresh_notification_attention(),public.run_scheduled_job(text,text,text),public.run_due_scheduled_jobs(integer),public.set_scheduled_job_enabled(text,boolean) to authenticated;

comment on table public.scheduled_jobs is 'Fixed local/staging job registry; job keys map to reviewed functions only.';
comment on table public.notification_delivery_attempts is 'Immutable provider-neutral safe delivery attempt history; no raw provider response or credential data.';

drop function public.complete_notification(uuid,uuid,text,text,text);
