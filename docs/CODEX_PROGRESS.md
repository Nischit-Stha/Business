# Codex progress

## Current task — Customer Self-Service Portal

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
