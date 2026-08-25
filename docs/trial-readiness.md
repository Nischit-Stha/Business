# Veera V2 controlled trial runbook

## Boundary and data

Trial and staging use synthetic records only. Set `VEERA_RUNTIME_MODE=trial`; the persistent banner must be visible. External email is blocked unless `ALLOW_EXTERNAL_PROVIDERS=true` is deliberately set. RENTA and STARR365 adapters are disabled and make no network calls. Never use production banking, government, signing, customer, or private document data.

## Environment and migration order

Copy `.env.example` into the deployment secret manager, not source control. Apply every file in `supabase/migrations/` in filename order to a separately controlled staging project. Run `supabase db lint` and the database test suite locally before `supabase db push --linked`; linking/pushing staging requires explicit approval. Do not run a reset against a linked project.

Supabase/Auth: use separate staging URL and keys, disable public signup, require email confirmation, allow only the exact staging callback URL, set one-hour JWT lifetime, enable refresh-token reuse detection, configure CAPTCHA/rate limits at the gateway, and use secure same-site cookies through `@supabase/ssr`. Configure custom SMTP using Resend after domain verification; invitation and recovery templates must link only to the exact staging origin. Recommended production policy is 12+ character passwords, leaked-password checks, MFA required for admins and strongly encouraged for staff, recovery notifications, global sign-out after password/admin access changes, and forced reauthentication (AAL2 or a session age under 10 minutes) before provisioning, financial corrections, exports, or security changes.

Storage: both document buckets stay private with the migration MIME allow-list/10 MiB limit. Keep server-side magic-byte validation, randomized object paths, 60-second signed URLs, access audit, and no caching. Test upload, denial, expiry and replacement with synthetic files.

Email: `EMAIL_PROVIDER=RESEND`, `RESEND_API_KEY`, `EMAIL_FROM`, and `RESEND_WEBHOOK_SECRET` live only in server secrets. Register `POST /api/webhooks/resend`; preserve the raw body and Svix headers. SENT is recorded after provider acceptance and DELIVERED only after a verified `email.delivered` event. Safe error categories are `TIMEOUT`, `RATE_LIMIT`, `INVALID_RECIPIENT`, `PROVIDER_UNAVAILABLE`, `REJECTED`, and `UNKNOWN`.

Scheduler: configure a supported platform cron (Vercel Cron via a small authenticated proxy, GitHub Actions with OIDC/secret, or a managed cloud scheduler) to POST `/api/scheduler/run` with `Authorization: Bearer $SCHEDULER_SECRET`. Use a random 32+ character secret, `SCHEDULER_ACTOR_USER_ID` for a dedicated active admin service identity, and a unique `X-Request-Id`. Never expose GET or unauthenticated execution. Database locks, fixed job keys, minute idempotency keys, immutable execution rows, bounded batches, retry-safe notification keys and a five-minute SQL timeout provide replay/overlap controls. Alert on HTTP failure, three consecutive job failures, stuck RUNNING rows, and duration approaching each job timeout.

## Trial reset

Only local development may use `npm run supabase:reset`. For staging, restore a reviewed synthetic baseline through forward migrations or restore a staging backup after verifying the project reference. The reset operator must confirm `VEERA_RUNTIME_MODE=trial`, the staging project ID, backup timestamp, and absence of real customer data. Never automate production reset.

## Backup, restore, rollback

Before migration, take a Supabase logical backup plus Storage inventory and record restore ownership. Test restore into a disposable project. Database migrations are forward-only: rollback means stop traffic/jobs/providers, restore the pre-change backup to a new staging project or ship a reviewed compensating migration, rotate affected secrets, then run smoke tests. Never edit immutable financial or audit history to roll back.

## Smoke test

- Banner says TRIAL / STAGING and admin environment status is correct.
- Staff/customer login, invitation, expiry/resend, password setup/recovery, disable/re-enable, and global session revocation work.
- Customer A cannot query Customer B; customer cannot open staff routes; staff cannot use portal context.
- Fleet/customer/payment/issue/maintenance/portal/toll-fine workflows load and controlled writes audit correctly.
- PDF/JPEG/PNG upload succeeds; executable/fake/oversize/path traversal attempts fail; signed URLs expire.
- Local provider is default. If external email is approved, send only to designated synthetic inboxes and confirm SENT/DELIVERED/error logging.
- Scheduler rejects missing/wrong tokens, accepts POST once, returns the same minute execution on replay, and records failures safely.
- Health endpoint, logs, alerts, backups, and restore contact are checked; no secrets or raw provider/customer data appear in logs.

## RENTA and STARR365

Contracts live in `apps/web/src/lib/external-adapters.ts`. RENTA covers create/update payloads, e-signature submission, signing status, signed-PDF retrieval and external document references. STARR365 covers supported customer/vehicle lookup, toll/fine import, transfer status and operational synchronization. Capability, authentication, webhook, rate-limit, retention, data residency and official API documentation must be confirmed with each vendor before implementing. Adapters remain disabled by default.
