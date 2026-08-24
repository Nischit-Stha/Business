# Codex progress

- **Current task:** Veera V2 staged messaging/reminder delivery infrastructure
- **Status:** PASS — implementation and all requested local verification are complete. No commit or production operation was performed.
- **Scope:** Provider-independent SMS/email interface with WhatsApp-ready channel types; FAKE provider only; durable leased queue; ten reminder templates; payment and operational reminder generation; preferences/suppression; exceptions; and staff Messaging UI.
- **Database:** Added forward-only migration `20260824090000_staged_messaging_delivery.sql`. Existing document-storage migrations, policies, and upload flows were not changed.
- **Delivery guarantees:** Stable logical keys and unique reminder-action linkage prevent duplicates. Claims use `FOR UPDATE SKIP LOCKED`, claim tokens, leases, bounded attempts, and exponential retry. Payment clearing cancels pending deliveries and active promise-to-pay suppresses them.
- **Security:** Messaging tables use deny-by-default RLS with active-staff read policies. Mutations are guarded server functions. Internal queue helpers are unavailable to browser roles. The server-only fake provider rejects real recipients and has no credentials.
- **UI:** `/messaging` shows queued, retrying, sent, failed, and suppressed delivery groups with inspection, safe retry, cancellation, generation, and fake-worker controls.
- **Tests:** Added provider unit tests and pgTAP coverage for uniqueness, fake success/retry/permanent failure, retry limit, payment clearing, opt-out, missing contact, repeated failure exceptions, disjoint claims, and unauthorized/inactive denial.
- **Compliance:** `docs/messaging-delivery.md` records the mandatory production legal, consent, privacy, template, provider-security, and operational review gate. No real provider may be enabled before approval.
- **Verification results:** `npm run lint` PASS; `npm run typecheck` PASS; `npm test` PASS (17 tests); `npm run build` PASS (21 generated pages); `npm run supabase:reset` PASS; `npm exec supabase -- test db` PASS (163 assertions across 7 files); `npm exec supabase -- db lint --local` PASS; `git diff --check` PASS.
- **Git status:** Changes remain uncommitted as requested.
- **Stop point:** Stop after this messaging task; do not resume document-storage work.
