# Deployment and technical runbook

Veera environments are strictly separate: local (`veera-v2-local`), isolated staging, and production. Never link local reset commands to a remote project. Never copy production data or secrets into local/staging.

## Pre-Deploy Checklist

- Run lint + tests
- Confirm RLS policies on all exposed tables
- Confirm no service-role key in frontend
- Confirm storage bucket privacy and policies

## Database Change Process

1. Apply migrations in staging first.
2. Run smoke tests for pickup/dropoff/swap/admin.
3. Backup DB before production migration.
4. Apply production migration and verify queries.

Exact staging sequence:

1. Provision a new Supabase project and web host labelled staging; record project ref and owners.
2. Set the exact HTTPS staging origin in `NEXT_PUBLIC_APP_URL`, Supabase Site URL and only the required `/auth/callback` allow-list entry.
3. Store anon, service-role, scheduler and provider secrets in host secret storage. Confirm no server secret has a `NEXT_PUBLIC_` prefix.
4. Set `VEERA_RUNTIME_MODE=trial`, keep `ALLOW_EXTERNAL_PROVIDERS=false`, `RENTA_INTEGRATION_ENABLED=false` and `STARR365_INTEGRATION_ENABLED=false` initially.
5. Take a baseline backup; link the CLI only after independently checking the staging project ref. Run schema lint/tests locally, then `supabase db push --linked`—never reset a linked project.
6. Load the reviewed synthetic UAT seed through a controlled SQL session. Confirm the trial banner and synthetic records before allowing access.
7. Deploy the web app, then run Auth, route isolation, private Storage, scheduler-auth and workflow smoke tests.
8. Only after domain verification and explicit approval, configure Resend/Supabase SMTP with synthetic inboxes and enable external email for staging. Verify signed webhooks and SENT→DELIVERED.
9. Configure managed POST cron with the scheduler secret and dedicated active admin actor. Alert on HTTP failure, three job failures and stuck executions.
10. Record UAT approval, backup/restore evidence and rollback owner. Do not promote staging data to production.

## Rollback Plan

- Keep reversible migration scripts.
- Snapshot/back up before each release.
- Roll back app and DB in lockstep.

## Monitoring

- Track JS/runtime errors.
- Track Supabase policy denial errors.
- Alert on failed booking submissions and storage failures.
- Alert on Auth abuse/rate limits, failed webhooks, repeated scheduler/provider failures, stuck jobs and expiring compliance.

## Secrets and providers

Rotate exposed/suspected secrets immediately. Resend, SMTP, scheduler, service-role and future integration credentials are server-only. RENTA, STARR365 and bank adapters remain disabled unless separately reviewed. The synthetic CSV workflow remains the bank fallback.

## Troubleshooting and rollback

- Auth redirect loop: compare the browser origin and callback against the exact Supabase allow-list; do not add wildcards.
- Storage denial: confirm staff/customer context and bucket policy; do not make a bucket public.
- Scheduler 401/503: validate secret/actor configuration without logging values; keep jobs stopped until corrected.
- Provider failure: disable external providers, retain queued work and use safe error categories.
- Migration failure: stop traffic/jobs, preserve logs, restore the pre-change backup into a new isolated project or ship a reviewed forward compensating migration. Roll back app and database in lockstep.
