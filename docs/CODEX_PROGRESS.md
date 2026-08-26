# Codex progress

## VEERA V2 AUTONOMOUS COMPLETION SPRINT

**Status:** Safe repository work completed and verified locally on 2026-08-26. Branch remains `veera-v2`; no merge, push, remote deployment, production access, real data or real provider connection occurred.

### Starting repository state

- Started from commit `ddeb071` (`veera-v2-trial-ready`) plus the uncommitted staging/UAT work documented below.
- Existing customer, fleet, assignment, agreement/payment, reconciliation, maintenance, issue, toll/fine, portal, notification, scheduler, Auth and private-document foundations were already implemented and extensively tested; they were preserved.
- `docs/current-state-matrix.md` records the audited classification used to avoid redoing verified work.

### Phases completed or safely extended

- Finished local staging/UAT deliverables: structured issue register, realistic 150-vehicle demo data, representative responsive checks, performance evidence and demo path. Credential-dependent remote actions remain explicit blockers.
- Added controlled rent-to-own completion: stored contract/schedule progress, amount paid/remaining balance, immutable administrator confirmation of external/legal transfer and a database guard preventing premature completion. Veera never performs ownership transfer.
- Added **Today**, a direct daily staff task hub, and **Reports**, a compact trustworthy management snapshot without invented KPIs.
- Replaced the full-ledger payments page read with bounded server-side Due/Overdue/Upcoming/Paid queues including customer, car, amounts, overdue age and reminder state.
- Added audited administrator control of customer-visible PayID instructions. No bank/PayID connection was added.
- Added invitation expiry to the fixed scheduler registry. Existing controlled portal rescheduling, document/request notifications and document aging were verified and retained.
- Expanded the portal issue category list to match the complete staff model.
- Added a provider-neutral disabled bank-feed boundary, a 500-vehicle synthetic scale extension, and future data-migration/integration runbooks.
- Added/updated demo, business value, staff operations, technical deployment, production readiness and integration documentation.

### Phases skipped because already complete

- Customer approval/readiness; safe vehicle allocation and overlap protection; ordinary payment allocation/reversal; synthetic reconciliation; owner exceptions; portal request decisions with atomic schedule application; private document versioning; issue timeline; maintenance intervals/odometer/workshop rules; toll/fine custody matching; notification retry/deduplication/delivery attempts; Auth invitations/recovery; RENTA/STARR365 disabled interfaces; and security hardening already had working implementations and regression coverage.
- Secure issue/service attachments were not added: the requested evidence can already be stored through the reviewed private document system, while a new attachment schema would expand sensitive-file scope without a demonstrated operational need.
- No dead V1 or legacy messaging code was removed because it was not proven safe to delete during this sprint.

### UX, security and scale findings

- UX: staff can begin at Today, routine payments no longer render the entire schedule ledger, RTO completion language distinguishes operational completion from legal transfer, and PayID visibility is explicit/audited.
- Security: new mutations are server-authorized; RTO and payment-setting evidence is immutable/attributable; public projections remain staff-gated; external adapters fail closed; no secrets entered source.
- Scale: 500 vehicles/335 customers loaded successfully. Local PostgreSQL timings were approximately 16 ms for the 500-row fleet projection, 6 ms for a 250-row customer summary and 0.8 ms for the bounded overdue-payment queue. The scaled browser payments smoke improved from roughly 29 seconds to 8 seconds on first dev compilation; deployed production timing still requires staging measurement.

### Tests and totals

- `npm run lint` — PASS.
- `npm run typecheck` — PASS.
- `npm test` — PASS: 29 tests across 8 files.
- `npm run build` — PASS: 49 routes/pages including `/today` and `/reports`.
- `npm run supabase:reset` — PASS on the unlinked local project.
- `npm exec supabase -- test db` — PASS: 401 assertions across 16 SQL files.
- `npm exec supabase -- db lint --local` — PASS.
- `npm run test:e2e --workspace=@veera/web` — PASS: 23 tests against 500-vehicle synthetic scale.
- `npm audit` — PASS: 0 vulnerabilities.
- `git diff --check` — PASS.

### Commits and deployment state

- No checkpoint commit was created; the sprint remains an uncommitted reviewable diff. No push was attempted.
- Local staging-equivalent is operational. Remote staging Supabase/web host, exact public Auth origin, staging secrets, Resend domain/inboxes and managed scheduler caller were unavailable and therefore not deployed/configured.
- Production integrations still absent: real bank/PayID feed, government systems, RENTA, STARR365, SMS/WhatsApp and production customer email.

### Readiness and remaining HIGH risks

- **Demo readiness:** ready for a supervised local synthetic demo using the demo guide and seed. Remote/email/managed-cron demonstration remains blocked externally.
- **Trial readiness:** application-level foundation is strong, but real-user trial is blocked on isolated staging, provider certification, rate limits/CAPTCHA, monitoring/support ownership, backup restore evidence, accessibility/security review and UAT approval.
- **Production readiness:** not ready. Highest risks are infrastructure/security operations, mandatory admin MFA enrolment, malware scanning, independent penetration/RLS review, privacy/legal/retention decisions, real-data migration reconciliation and incident/DR readiness.

### Recommended next human actions

1. Provision and approve the exact isolated staging Supabase project, web origin/domain, secrets, backup owner and alert owner.
2. Execute `docs/deployment.md`, then conduct independent keyboard/screen-reader and RLS/IDOR/Storage review.
3. Verify Resend/Supabase SMTP only with synthetic staging inboxes; configure managed cron and exercise failure alerts.
4. Review agreement/RTO wording, PayID instructions, privacy/retention and trial support with the business/legal owners.
5. Run a measured Veera demo/UAT, close every BLOCKER/HIGH item in `docs/UAT_ISSUES.md`, then approve a small real-user trial separately.

### WHAT VEERA CAN DO NOW

Veera can manage customers, fleet readiness/custody, three agreement types, weekly obligations and staged reconciliation, maintenance/compliance, issues, tolls/fines, documents, notifications, automation, daily work, owner exceptions and trustworthy management totals as one server-controlled system.

### WHAT STAFF CAN DO NOW

Staff can approve customers, allocate safe cars, create agreements, complete pickups/returns, record/reconcile/correct payments, manage service/issues/tolls/documents/requests, review automation and work from Today. Administrators can explicitly approve PayID instructions and confirm an externally completed RTO ownership transfer.

### WHAT CUSTOMERS CAN DO NOW

Customers can accept provisioned access, sign in/recover passwords, see their own car/agreement/payments/service/notifications, upload and securely view approved own documents, report issues, request schedule/contact changes, track safe responses and sign out.

### WHAT IS STILL NOT CONNECTED

No real bank/PayID feed, government service, RENTA, STARR365, SMS/WhatsApp or production email is connected. Remote staging and managed scheduling are not provisioned.

### WHAT MUST HAPPEN BEFORE REAL CUSTOMER DATA

Approve the migration mapping/dry-run/reconciliation plan, privacy and retention rules; provision isolated staging with monitoring/backups; complete independent security/accessibility review; certify providers; and obtain explicit business UAT approval.

### WHAT MUST HAPPEN BEFORE PRODUCTION

Close `docs/production-readiness-checklist.md`, including MFA, WAF/rate limits, malware scanning, telemetry/on-call, restore exercise, penetration test, legal/privacy/provider approvals, incident response and formal go-live/rollback ownership.

## Current task — Staging Deployment and UAT Sprint

**Status:** Local staging-equivalent sprint completed on 2026-08-25 with synthetic data only. No production system or real customer, banking, government, RENTA, STARR365, SMS, or email provider was connected. Remote staging deployment is blocked because an isolated Supabase project, web host, public staging origin, secrets, and provider accounts were not supplied.

### 1. Staging environment status

- Confirmed `supabase/config.toml` is an unlinked local project (`veera-v2-local`), then cleanly reapplied all 20 forward-only migrations and the default seed.
- Local Auth/API/PostgreSQL/Storage/Mailpit services were available. Auth sign-in and staff/customer separation passed in browser tests; both document buckets and signed-access authorization passed database tests.
- Trial/provider configuration remains fail closed: external providers, RENTA and STARR365 are disabled by default. No production flag was enabled.
- Remote staging Supabase/web deployment, exact redirect allow-list, backup/restore validation, CAPTCHA/rate limits and staging alert ownership remain BLOCKED pending provisioned infrastructure and an approved exact staging origin.

### 2. UAT workflows completed

- Staff browser smoke: owner dashboard, customer and vehicle lookup, payments, issue creation, maintenance, portal-request review, toll/fine review, and route separation.
- Customer browser smoke: invitation-ready login identity, portal dashboard, agreement/vehicle, payments, maintenance information, documents, issue/request pages, notification-visible portal data, password recovery entry, logout and cross-customer denial.
- Database workflow suites cover customer approval/documents, assignment/blocking/pickup/return, exact/partial/multi-week/manual payments, ambiguous reconciliation, reminders, maintenance lifecycle, toll/fine match/review/override/transfer, portal request decisions, immutable audit/financial history, notifications and owner exceptions.
- Scheduler database coverage passed for fixed job registry, staff/service boundary, locking, idempotency/duplicate prevention, bounded retry, failure isolation/history and repeated-failure owner attention. The managed HTTP caller/alert boundary remains untested without staging infrastructure.

### 3. UAT issues found/fixed

- Structured register: `docs/UAT_ISSUES.md`.
- Found 2 BLOCKER, 3 HIGH, 2 MEDIUM and 1 LOW issues.
- Fixed HIGH UAT-001 (missing realistic demo/scale seed), HIGH UAT-002 (null maintenance status crashed My Car), and LOW UAT-008 (redundant server-action form encoding warning).
- Open issues are not hidden: remote staging and Resend are BLOCKERs; managed scheduler configuration is HIGH; payments first-load performance and full assistive-technology review remain open.

### 4. Accessibility/responsive findings

- Browser checks cover 1440×900 desktop, 1280×800 laptop, 768×1024 tablet, and 430×932, 390×844 and 360×800 mobile widths across major staff and portal pages.
- Checked visible H1s, keyboard focus visibility and absence of document-level horizontal overflow. Existing semantic labels, status text (not color-only), responsive cards/tables and private-upload guidance remained intact.
- No responsive blocker was found. Full axe, screen-reader and manual contrast/touch-target certification remains before a real-user trial.

### 5. Security validation

- 382 database assertions passed across 15 files, including cross-customer IDOR denial, base-table isolation, private Storage, signed-access authorization, immutable financial/audit history, duplicate controls and provider/scheduler boundaries.
- Browser tests passed staff/customer route separation and direct Customer A → Customer B projection denial.
- Environment tests passed fail-closed external-provider configuration. `npm audit` found 0 vulnerabilities; schema lint found no errors; no secret was added to source.
- Staging-only gateway rate limits/CAPTCHA, real webhook receipt verification and an independent non-destructive security review remain required after infrastructure provisioning.

### 6. Performance findings

- Synthetic scale: 150 vehicles, 100 customers, 60 active agreements, 1,560 weekly schedule items and representative issues, maintenance, notifications and exceptions.
- Local PostgreSQL measurements: owner metrics about 2.3 ms, fleet projection about 13.2 ms, customer operational summary about 5.0 ms.
- The first dev-server browser load of `/payments` took roughly 24–26 seconds at scale. This is open as UAT-003; measure the deployed production build before adding a paginated/server-grouped read model.

### 7. Demo dataset

- Added `supabase/seed.uat.sql`, an additive, idempotent, synthetic-only UAT seed with explicit synthetic staff audit attribution.
- It includes available and assigned vehicles, a workshop vehicle, overdue and fully paid schedules, an ambiguous synthetic payment, upcoming service, expired registration, pickup/return today, an open issue, a toll requiring review, a portal request and owner-attention inputs.
- The default seed remains intentionally small so deterministic pgTAP assertions are not polluted.

### 8. Demo walkthrough (10–15 minutes)

1. Owner dashboard: show only actionable exceptions and explain management by exception.
2. Fleet: filter available cars, open an assigned vehicle and show readiness blockers.
3. Customer/assignment: open a synthetic approved customer and connect customer, car and agreement.
4. Payments: show weekly schedule, overdue versus paid states and ambiguous reconciliation.
5. Reminders: show queued/scheduled/delivered synthetic notifications and retry-safe automation.
6. Maintenance: show upcoming service, workshop/off-road state and readiness restoration.
7. Customer portal: sign in as Avery Example and show car, agreement, payments and private documents.
8. Vehicle issue: show the open warning-light issue and its staff/customer lifecycle.
9. Toll/fine: review the ambiguous synthetic notice and custody evidence.
10. Owner queue: return to the exception queue and emphasize fewer calls, fewer manual checks and scalable fleet oversight.

### 9. Test totals

- `npm run lint` — PASS.
- `npm run typecheck` — PASS.
- `npm test` — PASS: 29 tests across 8 files.
- `npm run build` — PASS: 47 routes/pages.
- `npm run supabase:reset` — PASS, local unlinked project only.
- `npm exec supabase -- test db` — PASS: 382 assertions across 15 SQL files.
- `npm exec supabase -- db lint --local` — PASS: no schema errors.
- `npm run test:e2e --workspace=@veera/web` — PASS: 21 tests against the scaled UAT dataset, including representative responsive widths.
- `npm audit` — PASS: 0 vulnerabilities.
- `git diff --check` — PASS.

### 10. Blockers before Veera demo

- For a local supervised demo: no code blocker after final checks; use synthetic identities and the UAT seed only.
- For a remotely accessible staging demo: provision isolated Supabase/web projects, exact Auth callbacks, secrets, backup/restore ownership and smoke-test access.
- Resend delivery and managed scheduler demonstrations are blocked until staging-only provider/domain/inbox and cron/alert configuration exists.

### 11. Blockers before real-user trial

- Resolve all BLOCKER/HIGH items in `docs/UAT_ISSUES.md`.
- Complete real staging Auth/email/webhook/scheduler/storage smoke tests, rate-limit/CAPTCHA configuration, independent RLS/IDOR review, accessibility review, backup restore exercise and operational support/incident ownership.
- Keep real banking, government, RENTA, STARR365 and SMS disconnected until separately reviewed and approved.

### 12. Git status

- Sprint changes are uncommitted as requested. No commit or remote deployment was created.
- Changed files include the portal null-state fix, responsive E2E coverage, upload-form warning cleanup, this report, the UAT issue register and the synthetic UAT seed.

## Current task — Veera V2 Trial Readiness Sprint

**Status:** Implemented and verified locally on 2026-08-25. Not committed and not deployed. Only synthetic local fixtures were used; no real customer, banking, government, RENTA, STARR365, SMS, or production system was connected.

### 1. Completed workstreams

- Customer onboarding: administrator-only staff/customer invitations through Supabase Auth, 24-hour metadata lifecycle, expiry job, resend, password setup/recovery, active/disabled portal and staff links, global session revocation, and immutable security audit records. Supabase owns raw invite/recovery tokens; Veera never persists them.
- Account security: deny-by-default server role gates, fresh-session/AAL2 boundary for sensitive admin actions, MFA assurance-level integration point, password policy UI, session revocation, disabled Auth users, recovery enumeration resistance, and documented production Auth/rate-limit policy.
- Email: replaceable provider interface retained; Resend email adapter added with environment-only configuration, idempotency key, 15-second timeout, safe error categories, existing immutable delivery-attempt logging, SENT on acceptance, and DELIVERED from verified Svix webhook receipts. Local remains the default.
- Scheduler: authenticated POST-only endpoint, timing-safe bearer validation, service-role-only database wrapper bound to an active admin actor, fixed reviewed job registry, locking, minute idempotency/replay behavior, immutable execution/failure records, bounded batches, outer SQL timeout, request IDs and safe response summaries.
- E2E: Playwright and synthetic Auth fixtures added; 18 browser tests pass.
- Staging: complete environment/migration/Auth/Storage/email/scheduler/reset/backup/restore/rollback/smoke-test runbook added. Nothing was deployed.
- Security hardening: reviewed RLS, server actions, Storage/signed URLs, SSR Auth, CSRF assumptions, rate limits, uploads, traversal, IDOR, privilege escalation, redirects, logging/errors, dependencies and secrets. Safe fixes and severity-ranked residual findings are in `docs/security-review-trial.md`.
- Integration boundaries: typed, disabled-by-default RENTA and STARR365 adapters cover the requested operations and make no network calls.
- Trial mode: persistent non-production/synthetic-data banner, external-provider fail-closed guard, documented safe reset, and admin-visible environment status without secret values.

### 2. Provider choices

- Application email: Resend behind `NotificationProvider`; production-capable but not enabled or live-tested with credentials.
- Supabase Auth invitation/recovery email: Supabase custom SMTP, with Resend recommended in staging/production after domain verification.
- Local default: `LocalNotificationProvider`; external use requires both `EMAIL_PROVIDER=RESEND` and explicit `ALLOW_EXTERNAL_PROVIDERS=true` outside production.
- SMS was not added. RENTA and STARR365 remain disabled capability contracts only.

### 3. Auth and security changes

- New `account_invitations` and immutable `account_security_events` tables with admin-only RLS reads and controlled RPCs.
- New server-only Supabase admin client; service-role credentials are never referenced from browser code.
- New invite/setup/recovery/callback/admin access pages; callback has an allow-listed local redirect target.
- Disabling access updates the Veera role/account link, bans the Supabase Auth user and globally revokes sessions. Password updates revoke other sessions.
- Sensitive provisioning/disable/resend actions require an AAL2 session when available or a sign-in within ten minutes.
- Production policy recommends mandatory admin MFA, 12+ character passwords, leaked-password checks, exact redirect origins, one-hour JWTs, refresh-token reuse detection, gateway CAPTCHA/rate limits and forced reauthentication for sensitive/financial actions.

### 4. E2E coverage

- Staff: login, owner dashboard, customer lookup, vehicle lookup, payment review, issue creation page, maintenance action page, portal request review and toll/fine review.
- Customer: login, dashboard, payments, vehicle, document upload page, issue submission page, portal request page and logout.
- Authorization: customer denied staff route, staff denied customer context, and Customer A receives no Customer B portal projection rows.
- Fixtures are fixed synthetic `.example.test` identities loaded only by the local seed.

### 5. Staging readiness

- Ready for a controlled staging deployment review, secret provisioning, verified staging domain/Auth redirects, Resend domain/SMTP setup, scheduler secret/actor setup, backup validation and smoke/UAT execution.
- The app prevents accidental external provider use in non-production by default and visibly labels local/trial mode.
- No automatic production or staging deployment was performed.

### 6. Remaining blockers before Veera trial

- Provision an isolated staging Supabase project and host, secrets and exact Auth redirect allow-list; verify backup/restore and alert ownership.
- Verify a sending domain and synthetic inboxes, configure Resend/Supabase SMTP and webhook, then conduct delivery/SENT/DELIVERED testing with explicit external-provider approval.
- Configure the managed cron caller and dedicated active admin actor; test authentication, replay, overlap, timeout and alert behavior in staging.
- Complete staff/customer UAT, accessibility/device testing, privacy/legal/content review, operational support and incident procedures.
- Enable/test gateway rate limiting and CAPTCHA. Perform an independent focused RLS/IDOR/Storage security review before inviting trial users.

### 7. Remaining blockers before production

- Enforce MFA for all admins and deliver enrolment/recovery-code UX; add explicit high-risk financial reauthentication coverage.
- Add WAF/edge limits, malware scanning/quarantine, CSP/security headers, centralized privacy-approved security telemetry, CI SAST/secret/dependency scanning and retention policies.
- Complete independent penetration testing, disaster-recovery restore exercise, production monitoring/on-call readiness and formal go-live/rollback approval.
- Confirm official RENTA/STARR365 capabilities and contracts before enabling any adapter. Banking/government/SMS integrations remain out of scope and disconnected.

### 8. Files created/modified

- Database/tests: `supabase/migrations/20260825050000_trial_readiness_security.sql`, `supabase/seed.sql`, and a deterministic selector correction in `supabase/tests/owner_operations_test.sql`.
- Auth/admin/trial: account setup/reset, forgot-password, Auth callback, admin accounts/environment pages, account actions, server-only admin client, trial banner, auth/env/layout/login/style updates.
- Email/scheduler: Resend provider/factory/tests, worker safe-category mapping, verified webhook route and authenticated scheduler route.
- Integrations/E2E: `external-adapters.ts`, Playwright config and `e2e/trial-workflows.spec.ts`; package manifests/lockfile updated for Playwright and Svix.
- Documentation/config: `.env.example`, `docs/trial-readiness.md`, `docs/security-review-trial.md`, and this report.
- Unrelated untracked `apps/web/AGENTS.md` and `apps/web/CLAUDE.md` were preserved and not edited.

### 9. Test totals and verification

- `npm run lint` — PASS, zero warnings.
- `npm run typecheck` — PASS.
- `npm test` — PASS: 29 tests across 8 files.
- `npm run build` — PASS: 47 app routes/static pages, including new Auth/admin/scheduler/webhook routes.
- `npm run supabase:reset` — PASS against local project only, including migration and synthetic Auth seed.
- `npm exec supabase -- test db` — PASS: 382 assertions across 15 SQL files.
- `npm exec supabase -- db lint --local` — PASS: no schema errors or warnings.
- `npm run test:e2e --workspace=@veera/web` — PASS: 18 browser tests.
- `npm audit` — PASS: 0 vulnerabilities.
- `git diff --check` — PASS.

### 10. Git status

Working tree contains the uncommitted sprint modifications/new files listed above, plus preserved unrelated untracked `apps/web/AGENTS.md` and `apps/web/CLAUDE.md`. No commit was created.

## Current task — Staff frontend and UX transformation

**Status:** Implemented and verified locally on 2026-08-25. Not committed. No migrations, RLS policies, authorization rules, financial logic, operational workflows, credentials, or production data were changed.

### Architecture and design system

- Replaced the flat staff link row with a fixed, grouped application shell: desktop sidebar, active route state, tablet/mobile drawer, contextual top bar, staff identity, sign-out control, attention shortcut, skip link, and global search.
- Added reusable page header, breadcrumbs, metric card, status/severity badge, action, table, filter/search, empty/loading/error, form field, section card, and activity timeline primitives.
- Introduced consistent tokens for colour, type, spacing, borders, radii, elevation, focus states, breakpoints, and operational severity. Staff tables become labelled card-like rows on narrow screens; fleet and customer lists use purpose-built responsive cards.
- Kept data loading in server components and all writes in the existing server actions. No operational state moved to browser storage.
- Added a server-authorized global search route for vehicle registration/make/model, customer name, exact agreement ID, and issue description. Results expose operational summaries only and remain governed by staff RLS.
- Added shared route loading and customer-safe error boundaries. Raw database details are not rendered by the new states.

### Substantially redesigned pages

- `/owner` — contextual greeting, dominant severity-aware attention queue, exception filters, clearer metrics, and preserved assignment/resolution workflows.
- `/fleet` — live search, nine quick filters, responsive vehicle cards, status/readiness hierarchy, explicit blocker explanations, odometer, customer, maintenance, issues, and next movement.
- `/customers` — searchable CRM-style card list, operational filters, reduced PII in the list, licence/document attention, and clear status.
- `/payments` — staff-friendly due/overdue/upcoming/paid sections, outstanding values, overdue age, human status badges, useful empty states, and advanced reconciliation separated from routine work.
- `/portal` — mobile-first My Car hero, next payment/payment status/service summaries, customer-language quick actions, and attention-only supporting cards.
- `/search` — new grouped global operations search.
- All other staff routes inherit the redesigned responsive shell, navigation, form controls, tables, focus treatment, badges, and feedback states without losing their existing workflows.

### Files created

- `apps/web/src/components/ui.tsx`
- `apps/web/src/components/ui.test.tsx`
- `apps/web/src/components/staff-navigation.tsx`
- `apps/web/src/components/fleet-board.tsx`
- `apps/web/src/components/customer-list.tsx`
- `apps/web/src/app/search/page.tsx`
- `apps/web/src/app/loading.tsx`
- `apps/web/src/app/error.tsx`
- `apps/web/src/app/operations.css`
- `apps/web/src/app/workflows.css`
- `apps/web/src/app/portal.css`
- `docs/frontend-transformation-plan.md`

### Files modified

- `apps/web/src/components/staff-nav.tsx`
- `apps/web/src/app/layout.tsx`
- `apps/web/src/app/styles.css`
- `apps/web/src/app/owner/page.tsx`
- `apps/web/src/app/fleet/page.tsx`
- `apps/web/src/app/customers/page.tsx`
- `apps/web/src/app/payments/page.tsx`
- `apps/web/src/app/portal/page.tsx`
- `apps/web/vitest.config.ts`
- `docs/CODEX_PROGRESS.md`

### Backend limitations retained for review

- Fleet filtering is intentionally client-side over the existing `fleet_operations` result. At roughly 150 vehicles this is responsive; significant scale needs a reviewed paginated/search RPC or server query rather than loading the full fleet.
- The customer list source currently exposes core customer records but not a single safe projection joining active agreement, vehicle, payment, document, issue, and portal status. The redesigned list therefore avoids inventing those fields; an operational customer-summary view would enable the full requested filter set efficiently.
- The vehicle detail sources do not currently provide one consolidated movement/current-agreement/payment projection. Existing maintenance, compliance, issue, document, and edit capabilities remain available, but ideal decision tabs require a reviewed read model.
- Pickup/return checklists have scheduling and completion state but no explicit persisted readiness-reason/checklist-step projection, so blockers cannot yet be presented with the same precision as fleet allocation readiness.
- Issues do not expose a reliable “my issues” identity filter or a distinct waiting-state model in the current route query. Notifications likewise do not have a separate staff-facing “needs attention” projection beyond status grouping.
- No chart was added because the current owner payload supplies point-in-time metrics, not a trustworthy time series.

### Verification

- `npm run lint` — PASS.
- `npm run typecheck` — PASS.
- `npm test` — PASS, 25 tests across 7 files, including 4 shared UI presentation/accessibility tests.
- `npm run build` — PASS, 37 generated routes including the new `/search` route.
- `npm run supabase:reset` — PASS against local Supabase only.
- `npm exec supabase -- test db` — PASS, 338 assertions across 14 files.
- `npm exec supabase -- db lint --local` — PASS, no schema errors.
- `git diff --check` — PASS.

No commit was created. The pre-existing uncommitted working tree was preserved.

## Previous task — Customer Self-Service Portal

**Status:** Implemented and verified locally on 2026-08-25. Not committed. No production connection, real provider, credential, or real customer data was used.

### Files created

- `supabase/migrations/20260825010000_customer_self_service_portal.sql`
- `supabase/tests/customer_portal_test.sql`
- `apps/web/src/components/portal-nav.tsx`
- `apps/web/src/lib/portal-actions.ts`
- `apps/web/src/app/portal/page.tsx`
- `apps/web/src/app/portal/login/page.tsx`
- `apps/web/src/app/portal/access-denied/page.tsx`
- `apps/web/src/app/portal/payments/page.tsx`
- `apps/web/src/app/portal/my-car/page.tsx`
- `apps/web/src/app/portal/issues/page.tsx`
- `apps/web/src/app/portal/documents/page.tsx`
- `apps/web/src/app/portal/profile/page.tsx`
- `apps/web/src/app/operations/portal-requests/page.tsx`

### Files modified for this task

- `apps/web/src/lib/auth.ts` — separate `requireCustomer` guard.
- `apps/web/src/components/staff-nav.tsx` — staff portal-request queue link (also contains the preceding notification change).
- `apps/web/src/app/styles.css` — mobile portal cards, navigation, payment hero, lists, and responsive layout.
- `docs/CODEX_PROGRESS.md` — this report.

The working tree also contains the preceding uncommitted Notification and Reminder Engine files and modifications listed later in this document; they were preserved.

### Database changes

- Added `customer_portal_accounts`, a one-auth-user-to-one-customer access link with active/disabled state and RLS.
- Added audited, admin-only `set_customer_portal_access` provisioning/disable RPC.
- Added private `app_private.portal_customer_id()` identity resolution from `auth.uid()`.
- Added `customer_portal_requests` for pickup/return reschedule requests and contact-detail change requests. Customers cannot directly change schedules or profile records.
- Added `business_payment_settings`; PayID text is returned only when explicitly approved. The seed contains no PayID or bank details.
- Extended `vehicle_issues` with `STAFF`/`CUSTOMER_PORTAL` source attribution and portal reporter identity while retaining staff-created issue behavior.
- Added deliberately column-limited portal projections for profile, agreements/RTO summary, payment schedule, sanitized receipts, maintenance, documents, notifications, issues, pickups, returns, and approved payment instructions.
- Operational base tables remain staff-only under RLS. Customer-safe projections are owner-evaluated, security-barrier views that filter every query by the authenticated user's active portal link; customers cannot query raw base rows.
- Added controlled RPCs for issue submission, reschedule requests, and contact change requests.
- Added audit actions for portal access changes, issue submission, reschedule requests, and profile-change requests.

### Features implemented

- Separate customer sign-in, access-denied flow, route guard, sign-out, and minimal mobile navigation. Staff routes continue to require active staff profiles.
- Mobile home dashboard with current vehicle/agreement, next payment and overdue amount, pickup/return, maintenance warning, licence/document attention, open issues, and sanitized recent notifications.
- Agreement details and supported rent-to-own totals/payment counts on My Car without inventing missing values.
- Payment schedule with human-readable statuses, next/overdue amounts, sanitized receipt records, and neutral payment-instructions fallback.
- Maintenance view with odometer, last/next service, kilometres remaining, status, and scheduled appointment, excluding cost/notes/vendor diagnostics.
- Customer issue reporting with controlled category/severity, automatically linked active vehicle/agreement, fixed initial `OPEN` state, no assignee control, staff visibility, source attribution, and reuse of existing owner-attention/blocking rules.
- Customer-safe issue status mapping without assignee, audit, internal notes, or staff resolution commentary.
- Pickup/return schedule and actual status with request-only rescheduling.
- Customer document status and receipt area without direct storage URLs or vehicle compliance documents.
- Profile view with request-only phone/email changes; legal name and licence identity fields are not directly editable.
- Staff page for portal-originated requests.
- Empty states throughout the portal and a responsive card/list layout rather than admin tables.

### Security controls

- Customer identity is resolved server-side from the authenticated user; browser-supplied customer IDs are never used by portal reads or writes.
- Base customers, vehicles, agreements, payment ledger, notifications, issues, maintenance, and storage metadata remain inaccessible to customer sessions.
- Portal projections enumerate allowed columns and apply authenticated customer filtering, preventing cross-customer direct-object access.
- Mutation RPCs repeat active portal authorization and derive vehicle/agreement/customer context internally.
- Raw payment references/descriptions/notes, reconciliation data, VIN, notification recipients/provider/failure data, internal issues, maintenance costs/notes, audit events, owner attention, storage paths, and private URLs are excluded.
- Private Storage remains server-controlled; the portal creates no unrestricted file URL.
- Portal access provisioning is admin-only and audited; customer issue/request actions are audited.
- All test identities, contacts, vehicles, and payment data are synthetic.

### Tests and results

- Added 31 portal pgTAP assertions covering own/cross-customer profile, agreement and vehicle access; base-table denial; sanitized payments/receipts; document isolation; controlled issue creation/internal-field protection; notification sanitization; maintenance cost/note hiding; unapproved PayID empty state; and direct-object reschedule denial.
- `npm run lint` — PASS.
- `npm run typecheck` — PASS.
- `npm test` — PASS, 21 tests across 6 files.
- `npm run build` — PASS, 35 routes including all portal and staff request routes.
- `npm run supabase:reset` — PASS through both uncommitted notification and portal migrations.
- `npm exec supabase -- test db` — PASS, 321 assertions across 13 files.
- `npm exec supabase -- db lint --local` — PASS, no schema errors.
- `git diff --check` — PASS.

### Customer calls this can reduce

- “What car/agreement do I have and what is its status?”
- “What is due next, am I overdue, and was my payment received?”
- “When is pickup/return, and can I ask for another time?”
- “When is the car due for service?”
- “What is happening with the vehicle problem I reported?”
- “What is my licence/document status?”
- “What notifications has Veera sent?”
- Routine requests to update phone or email details.

### Remaining gaps before real customer use

- Customer accounts require controlled staff/admin provisioning; there is no invitation, password-reset onboarding, MFA policy, or account-recovery UI.
- No end-to-end browser test signs in through a real Supabase session; authorization is covered at the database layer and all portal routes are production-build verified.
- Signed rental agreement file access and customer document upload are not exposed because current private Storage is staff/server controlled. A reviewed signed-download/upload flow and document access audit are still needed.
- Portal requests are staff-visible but do not yet have staff approve/decline/complete controls or customer-facing response messages.
- No real payment, SMS, email, WhatsApp, or signing provider is connected. There is no online payment action.
- No approved PayID setting exists, so the portal intentionally shows the neutral contact message.
- Receipt references are deliberately generic because the ledger has no separately approved customer-display reference field.
- Issue attachments/photos, emergency workflow integration, push updates, notification delivery receipts, and customer acknowledgement are not implemented.
- Accessibility/device testing, branded content review, privacy/legal review, rate limiting, bot protection, production session policy, support process, and staging user acceptance remain.

### Git status

No commit was created. Portal files are untracked except for modifications to `auth.ts`, `staff-nav.tsx`, `styles.css`, and this progress report. The preceding notification-engine working tree remains uncommitted. `docs/CODEX_PROGRESS updated.md` was restored exactly after a status check found it unintentionally absent. `git diff --check` is clean.

## Previous task — Notification and Reminder Engine

**Veera V2 Notification and Reminder Engine — repository verification and progress reporting**

Verification date: 2026-08-25 (Australia/Melbourne)

Build a durable, provider-neutral notification system for payment, maintenance, licence, pickup, return, and issue workflows without connecting a real SMS, email, WhatsApp, or banking provider.

## Implementation status

**Implemented in the working tree; not committed.**

The repository contains a forward-only notification migration, database and provider tests, a server-side queue worker and actions, a notification operations page, issue notification controls, a sanitized customer timeline, navigation, and operating documentation. The migration applies locally and the recorded validation suite passes.

This is an internal/local delivery foundation, not production-provider readiness. The existing staged `/messaging` subsystem remains alongside the new `/notifications` subsystem.

## Files created

- `supabase/migrations/20260825000000_notification_reminder_engine.sql` — schema, templates, settings, RLS, auditing, generation, claiming, completion, retry, cancellation, and manual queue RPCs.
- `supabase/tests/notification_engine_test.sql` — 20 pgTAP assertions covering lifecycle and security boundaries.
- `apps/web/src/app/notifications/page.tsx` — staff operations page.
- `apps/web/src/lib/notification-actions.ts` — staff-authorized server actions.
- `apps/web/src/lib/notification-worker.ts` — server-only claim/deliver/complete loop.
- `apps/web/src/lib/notification-provider.ts` — provider interface and non-networking local adapter.
- `apps/web/src/lib/notification-provider.test.ts` — local provider tests.
- `docs/notification-reminder-engine.md` — operating and provider-readiness documentation.
- `docs/CODEX_PROGRESS.md` — this verified report.

## Files modified

- `apps/web/src/app/customers/[id]/page.tsx` — sanitized notification timeline.
- `apps/web/src/app/operations/issues/[id]/page.tsx` — issue notification controls.
- `apps/web/src/components/staff-nav.tsx` — `/notifications` navigation entry.
- `apps/web/src/lib/issue-actions.ts` — server action for customer-safe issue notifications.

No existing V1 files were modified or removed.

## Database changes

- `notification_templates` with controlled keys for `PAYMENT_DUE`, `PAYMENT_OVERDUE`, `PAYMENT_RECEIVED`, `SERVICE_DUE`, `SERVICE_OVERDUE`, `LICENCE_EXPIRING`, `LICENCE_EXPIRED`, `PICKUP_REMINDER`, `RETURN_REMINDER`, `ISSUE_CREATED`, and `ISSUE_STATUS_UPDATE`; each declares a channel, optional subject, message, active state, and safe-variable allow-list.
- `notification_settings` with adjustable payment, licence, pickup, return, and bounded retry configuration.
- `notifications` with customer/vehicle/agreement/issue context, type/channel/template, frozen content, scheduling and delivery timestamps, lifecycle status, retry/failure/provider fields, creator/timestamps, and internal deduplication/claim fields.
- Queue and customer-history indexes; updated-at and sent-history protection triggers.
- Staff-read RLS policies with authenticated direct writes revoked.
- Audit action extensions for notification creation, manual queueing, cancellation, retry, claim/status lifecycle names.
- Private rendering and queue helpers.
- Staff-authorized RPCs: `generate_notifications`, `queue_supported_notification`, `claim_notifications`, `complete_notification`, `retry_notification`, and `cancel_notification`.

## Features implemented

- Durable PostgreSQL notifications; no browser-storage operational state.
- Frozen rendered subject/message history, with sent/delivered content protected from edits.
- Literal `{{variable}}` rendering with per-template allow-lists and rejection of unknown, missing, or unresolved variables.
- Payment due-day and 1/3/7-day overdue generation from payment schedule items.
- Unique obligation/stage keys preventing duplicate reminders.
- Cancellation of unsent payment notifications when obligations become paid or waived.
- Maintenance due-soon/overdue generation for active assignments, condition deduplication, and cancellation when cleared.
- Licence 30/14/7-day and expired stages for active customers with active or pending-signature agreements.
- Pickup and return 24-hour/same-day stages from explicit schedules, cancelled when completed or cancelled.
- Staff-initiated issue-created and issue-status/resolution-safe messages; internal issue content is excluded.
- Manual queueing for supported reminder types.
- `FOR UPDATE SKIP LOCKED` claims, claim tokens, expiring leases, and bounded batch sizes.
- Bounded exponential retries and terminal failure state.
- Repeated-failure operational exceptions for owner attention.
- Synthetic `local:<notification-id>` provider IDs, simulated failures, and no network delivery.
- Staff inspection, generation, local processing, retry, and cancellation workflows. Sent rows have no edit action.
- Sanitized customer history limited to time, type, channel, and status.

## Tests and recorded results

These commands passed against the current implementation after the final migration reset:

- `npm run lint` — passed with zero warnings.
- `npm run typecheck` — passed.
- `npm test` — 6 files and 21 tests passed, including 2 notification-provider tests.
- `npm run build` — passed; `/notifications` is present as a dynamic route.
- `npm run supabase:reset` — passed, including the notification migration and seed.
- `npm exec supabase -- test db` — 12 files and 290 tests passed, including all 20 notification assertions.
- `npm exec supabase -- db lint --local` — no schema errors.
- `git diff --check` — passed.

Notification database coverage verifies generation, deduplication, 1/3/7-day overdue escalation, licence and maintenance stages, pickup cancellation, disjoint claims, claim-token enforcement, sent-state preservation, retry exhaustion, owner attention, template safety, sent-content immutability, RLS, and worker authorization.

## Security notes

- RLS is enabled and only active staff can read notification tables through policy.
- Authenticated direct mutation is revoked; writes use staff-checking security-definer RPCs.
- Private renderer and queue helpers are revoked from public, anonymous, and authenticated callers.
- No service-role key, provider token, password, production credential, or real endpoint was added.
- The local provider performs no network calls.
- Templates omit licence numbers/images, addresses, document URLs, bank descriptions, credentials, and internal issue notes.
- Licence messages use only first name and expiry date.
- Customer history excludes recipients and provider/debug failure metadata.
- Tests use synthetic identities and contacts.

## Remaining gaps

- No real SMS, email, or WhatsApp adapter is connected, as required for this stage.
- No scheduler invokes generation or processing automatically; staff actions currently trigger both paths.
- `PAYMENT_RECEIVED` has template/model support but is not automatically queued when a receipt is posted.
- Stored payment stages cover due-day/overdue defaults, but negative pre-due stages are not correctly classified as `PAYMENT_DUE`; configurable before-due reminders remain incomplete.
- Completion records `SENT`; no provider webhook/receipt path transitions rows to `DELIVERED` or fills `delivered_at`.
- There is no separate immutable per-attempt delivery table; attempt history is represented by retry count, state/audit changes, and terminal failure data.
- Missing-contact and preference suppression create `SUPPRESSED` rows but no dedicated unresolved-contact owner exception. Repeated terminal failures do create owner attention.
- Issue notifications are explicitly queued by staff rather than automatically coupled to each status transition.
- The operations page groups `SUPPRESSED` under Cancelled and has no filters, dedicated detail route, or pagination beyond its 300-row limit.
- Durable settings have no staff configuration UI.
- WhatsApp and `INTERNAL` are modeled but no seeded template uses them and the local adapter has no production channel behavior.
- Quiet hours, customer time zones, broader frequency caps, bounce/complaint handling, sender verification, signed webhooks, provider rate limiting, monitoring, dead-letter operations, and retention policy remain.
- The older `/messaging` implementation has not been migrated into or removed in favor of `/notifications`; consolidation needs separate review.

## Git status

The working tree is dirty and no commit was created.

Modified tracked files:

- `apps/web/src/app/customers/[id]/page.tsx`
- `apps/web/src/app/operations/issues/[id]/page.tsx`
- `apps/web/src/components/staff-nav.tsx`
- `apps/web/src/lib/issue-actions.ts`

Untracked files/directories:

- `apps/web/src/app/notifications/`
- `apps/web/src/lib/notification-actions.ts`
- `apps/web/src/lib/notification-provider.test.ts`
- `apps/web/src/lib/notification-provider.ts`
- `apps/web/src/lib/notification-worker.ts`
- `docs/CODEX_PROGRESS.md`
- `docs/notification-reminder-engine.md`
- `supabase/migrations/20260825000000_notification_reminder_engine.sql`
- `supabase/tests/notification_engine_test.sql`

`git diff --check` reports no whitespace errors. No commit was created.
# Portal request workflow and secure document exchange — 2026-08-25

- Added a six-state customer portal request lifecycle with staff assignment, customer-safe responses, audited decisions/completion, and controlled pickup/return rescheduling through the existing scheduling RPCs.
- Added staff request queues and a pending-document review queue.
- Added portal request history and customer uploads for driver licences and proof of address with content-signature checks, 10 MiB limits, sanitized names, server-generated private paths, immutable replacement history, and staff verification/rejection/replacement decisions.
- Added customer document access authorization with 60-second signed URLs generated server-side; storage paths and signed URLs are never exposed in portal projections or persisted.
- Added durable signed-agreement document types and a service-role registration boundary for already-signed PDFs, ready for a future Renta/signing-provider adapter without implementing e-signing.
- Added customer-safe notification templates for request/document/agreement events and owner exception refresh for delayed requests, repeated rejection, and missing required documents.
- Added pgTAP security/workflow coverage in `supabase/tests/portal_workflow_exchange_test.sql`.

# Tolls and fines automation — 2026-08-25

- Added the provider-neutral toll/fine model, requested types and lifecycle, deterministic custody/agreement matching, explicit confidence states, and immutable evidence snapshots.
- Added checksum/idempotency-protected synthetic CSV staging with server-side parsing/validation, duplicate external-reference handling, and per-row rejection reports.
- Added `/operations/tolls-fines` queues, manual entry, match inspection, staff confirmation/override/no-match actions, dispute and transfer lifecycle controls, and active-staff authorization.
- Added deduplicated owner attention for high-value unresolved fines, ambiguity, overdue transfers, repeated unmatched events, disputes, and assignment-history inconsistencies.
- Added an intentionally disabled customer-safe projection and documented the future Starr365 adapter boundary in `docs/tolls-fines-automation.md`.
- No real provider/government connection, production credential, customer portal access, or automatic liability transfer was added.

# Operational automation sprint — 2026-08-25

- Preserved and completed the toll/fine automation foundation with provider-neutral synthetic import, custody evidence, reviewed transfer workflow, and exception-only owner attention.
- Added a fixed local/staging scheduled-job registry, bounded due runner, locking/idempotency, failure isolation, immutable terminal execution history, audited controls, and `/operations/automation`.
- Completed payment-received notifications, configurable pre-due stages, immutable safe delivery attempts, internal delivery receipts, missing-contact attention, optional safe issue-status automation, bounded settings, and attention-first notification queues.
- Added staff-safe customer, vehicle, movement-readiness, issue-queue, and notification-attention read models; adopted them in customer filtering, vehicle detail, and pickup/return decision screens.
- Added focused pgTAP coverage for scheduler selection/locking/idempotency/failure isolation/authorization, notification completion, and read-model security/accuracy.
- No production cron, provider, webhook, Starr365, toll provider, VicRoads, government system, credential, or real customer data was introduced.
