# Controlled staging architecture

## Exact topology

`staging.veera.example` (replace with the approved staging-only hostname) is the only browser origin. It routes to one isolated staging web deployment. That deployment connects only to one isolated Supabase staging project (PostgreSQL, Auth and private Storage). Staging has separate host secrets, SMTP/provider accounts, logs, backups and operators. It has no network path or credentials for production customer data, banking, government systems, RENTA, STARR365, SMS/WhatsApp or production financial providers. Load only `supabase/seed.uat.sql` synthetic identities initially.

Use the exact final origin consistently:

- Web host: `NEXT_PUBLIC_APP_URL=https://staging.veera.example`
- Supabase Auth Site URL: `https://staging.veera.example`
- Supabase Auth additional redirect URL: `https://staging.veera.example/auth/callback` only
- OAuth callback, if a future reviewed provider requires one: the provider-specific Supabase callback displayed by the isolated staging project; do not add one now
- Local Site URL: `http://localhost:3000`; local redirect: `http://localhost:3000/auth/callback`
- Production must use its different exact HTTPS origin and project. Never use wildcard redirect origins.

## Environment inventory

| Variable | Classification | Staging value shape | Storage |
|---|---|---|---|
| `NEXT_PUBLIC_APP_URL` | public-safe | exact staging HTTPS origin | web host environment |
| `NEXT_PUBLIC_SUPABASE_URL` | public-safe | staging project API URL | web host environment |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | public-safe credential, RLS-constrained | staging publishable/anon key | web host environment; expected in browser |
| `VEERA_RUNTIME_MODE` | public-safe operational setting | `trial` | web host environment |
| `ADMIN_MFA_ENFORCEMENT` | public-safe policy | `rollout`, then `required` | web host environment |
| `ALLOW_EXTERNAL_PROVIDERS` | public-safe policy | `false` initially | web host environment |
| `EMAIL_PROVIDER` | public-safe category | `LOCAL`, later separately approved `RESEND` | web host environment |
| `RENTA_INTEGRATION_ENABLED`, `STARR365_INTEGRATION_ENABLED` | public-safe policy | `false` | web host environment |
| `UPLOAD_SCANNER` | public-safe capability flag | `unavailable` until an adapter is implemented | web host environment |
| `DEPLOYMENT_VERSION`, `MIGRATION_VERSION` | public-safe release identifiers | immutable release/migration ID | deployment pipeline environment |
| `STAGING_BACKUP_VERIFIED_AT` | public-safe evidence timestamp | empty until verified | deployment environment after recorded exercise |
| `SUPABASE_SERVICE_ROLE_KEY` | secret | staging-only service role | web host encrypted server secret store only |
| `SCHEDULER_SECRET` | secret, 32+ random bytes | staging-only bearer secret | web host and managed cron encrypted secret stores |
| `SCHEDULER_ACTOR_USER_ID` | restricted identifier | dedicated active staging admin UUID | web host encrypted/server-only config |
| `RESEND_API_KEY`, `RESEND_WEBHOOK_SECRET` | secret | staging provider credentials | web host encrypted secret store; webhook secret also in provider |
| `EMAIL_FROM` | public-safe address/config | verified staging-only sender | web host environment |
| `SUPABASE_DB_PASSWORD` | secret | staging database password | operator password manager/CI secret only; never web runtime |

No secret may use a `NEXT_PUBLIC_` prefix, enter source control, browser bundles, screenshots, logs, seeds or support tickets.

## Separation and promotion rules

Local uses local Supabase, Mailpit/LOCAL provider, localhost callbacks and synthetic seeds. Staging uses a unique project, domain, provider tenants and synthetic data; no database copy from production. Production is separately provisioned and never shares keys, users, Storage buckets, domains, web deployments, SMTP/API accounts, scheduler secrets or backups. Promote reviewed source and forward-only migrations—not databases, Auth users, Storage objects or environment files. `supabase db reset` is local-only. Remote staging receives reviewed migrations via an explicitly verified project ref; production linking requires a separate approved procedure.

## External edge policies (not implemented in this repository)

Configure Supabase Auth email/password limits and web-host WAF independently: login 10 attempts/IP/10 minutes then progressive challenge; recovery 3/account and 10/IP/hour with identical responses; invitation callback 20/IP/hour; portal mutation 60/IP/hour with authenticated application budgets beneath it; uploads 20/IP/hour and 100 MiB/hour; webhook and scheduler endpoints 60/IP/minute, POST only. Return 429 with `Retry-After`; do not disclose account existence. Alert on sustained limits. Trust client IP only from the hosting platform’s authenticated edge metadata.

Staging email must use a staging-only account and synthetic inbox allow-list. RENTA, STARR365, bank, government, RENTA, SMS and WhatsApp remain disabled. A malware scanner must inspect quarantined bytes and return a signed/provider-authenticated verdict before any object becomes available; the current adapter deliberately fails closed in trial/production.

## MFA rollout

1. Keep `ADMIN_MFA_ENFORCEMENT=rollout`; each admin enrolls TOTP and verifies access while a second administrator observes.
2. Record recovery owner and verify a second factor where possible. Never store QR seeds or OTPs.
3. Confirm every active admin reaches AAL2 and sensitive account actions redirect to MFA.
4. Set `required` in staging, start new sessions, and test lost-factor recovery using synthetic accounts.
5. Staff/customer accounts remain AAL1-compatible. Revert only the enforcement flag during a supervised lockout incident; do not weaken role authorization.
