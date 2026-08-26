# Veera V2 current-state matrix

Audited 2026-08-25 from branch `veera-v2` at `ddeb071`, including the uncommitted staging/UAT changes. “Complete” means the requested repository capability exists and has proportionate automated verification; it does not imply production configuration.

| Capability | State | Evidence / remaining boundary |
|---|---|---|
| Customer management | COMPLETE | CRUD, status, readiness summary, approval and audit |
| Fleet management | COMPLETE | CRUD, operational states, readiness and issue/maintenance/compliance projections |
| Agreements | COMPLETE | Three agreement types, lifecycle, schedules, custody and signed-document support |
| Rent-to-own | COMPLETE | Stored-term progress plus immutable external/legal transfer confirmation before staff completion; no automatic ownership transfer |
| Payments | COMPLETE | Immutable receipts, allocation, partial/multi-week/excess and compensating reversal |
| Payment reconciliation | COMPLETE | Synthetic CSV, matching, manual override, duplicate/reversal controls; no bank feed |
| Owner dashboard | FUNCTIONAL | Action-oriented metrics and exception queue; reviewed again after new views |
| Vehicle assignments | COMPLETE | Atomic server workflows, overlap exclusion and double-assignment protection |
| Pickups | COMPLETE | Scheduling, blockers, completion and audit |
| Returns | COMPLETE | Scheduling, condition/disposition, completion and audit |
| Issues | FUNCTIONAL | Categories, assignment, timeline, internal/customer-safe states and escalation; attachments absent |
| Maintenance | COMPLETE | 10,000 km default, per-vehicle interval, monotonic odometer, service history/cost/workshop readiness |
| Compliance | COMPLETE | Registration/RWC/licence exposure and allocation blockers |
| Notifications | FUNCTIONAL | Generation, deduplication, retry, attempts, receipts and attention; document/request templates incomplete |
| Scheduler | FUNCTIONAL | Fixed jobs including invitation expiry, locking, idempotency, history and failure attention; managed caller is external |
| Customer portal | FUNCTIONAL | Auth, dashboard, payments, car/service, documents, issues, requests and notifications |
| Documents | COMPLETE | Private buckets, signature/size limits, version history, review and short signed access |
| Portal requests | FUNCTIONAL | Full state model and staff decisions; schedule approval is not yet applied atomically |
| Tolls/fines | COMPLETE | Synthetic import, custody matching, ambiguity, override, dispute and transfer states |
| Authentication | COMPLETE | Invitations, recovery, disable/session revocation and deny-by-default role gates |
| MFA readiness | PARTIAL | AAL2/fresh-session boundary exists; enrolment/recovery UX and mandatory policy are external/configuration work |
| Email | BLOCKED_EXTERNAL | Resend/Supabase SMTP adapters and verified webhook exist; no staging domain/credentials/inboxes |
| Search | FUNCTIONAL | Staff-authorized cross-domain search; pagination/scale review required |
| Reporting | FUNCTIONAL | Dedicated trustworthy fleet/finance/maintenance/customer/operations snapshot; intentionally no invented KPIs |
| Security | FUNCTIONAL | RLS, private storage, SSR Auth, provider fail-closed and extensive tests; independent review/WAF remain |
| Staging | BLOCKED_EXTERNAL | Runbook and local staging-equivalent pass; no isolated remote project/host/origin supplied |
| E2E tests | FUNCTIONAL | 21 synthetic browser tests including route isolation and representative widths; connected mutation lifecycle needs expansion |
| External integrations | STUB | Disabled typed RENTA/STARR365 boundaries; no SMS/WhatsApp or bank provider connection |
| Production readiness | PARTIAL | Strong application foundation; infrastructure, provider, legal/privacy, DR, monitoring, security and UAT approvals remain |

This matrix is the routing document for the completion sprint: completed capabilities should receive regression coverage, not wholesale rewrites.
