# Independent security review checklist

This is a review aid, not a penetration-test certificate. A reviewer independent of the implementation records request/response evidence and migration/version IDs.

- RLS bypass: enumerate every exposed table/view/function and test anon, customer A, customer B, staff, admin and service role; inspect `security definer` search paths and grants.
- IDOR/cross-customer access: substitute every route, RPC and document identifier across synthetic tenants; ensure existence and metadata are not disclosed.
- Privilege escalation: mutate JWT/app metadata, role form fields and account status; verify server profile state is authoritative and admin MFA/AAL2 protects sensitive mutations.
- Storage authorization/signed URLs: verify buckets are private, object paths cannot be listed, privileged signing follows a prior authorization query, links expire, and paths never appear in UI/logs.
- Financial mutations: prove only permitted roles/functions can create immutable entries; corrections are compensating entries and retries preserve invariants.
- Audit immutability: attempt insert/update/delete as all non-service roles and check actor/time/context minimization.
- Webhook verification: absent, malformed, replayed and stale signatures fail before state change; provider bodies/secrets are not logged.
- Scheduler authorization: GET fails, missing/short/wrong bearer fails, actor must be active admin, responses contain safe categories only, and edge rate limits apply.
- CSRF assumptions: inventory cookie-authenticated mutations; verify SameSite cookies, same-origin forms, no permissive CORS, and add explicit Origin/CSRF tokens if cross-site deployment assumptions change.
- SSR/Auth boundary: use `getUser`, not client claims, before privileged reads; no service key enters client modules; cached personalized responses cannot cross users.
- Open redirects: callback and return paths use fixed relative allow-lists; test schemes, encoded slashes and protocol-relative forms.
- Secret/error leakage: inspect browser bundles, maps, headers, logs and error pages; provider/SQL errors are mapped to safe categories.
- Dependencies: review `npm audit`, lockfile integrity, maintainer advisories and runtime support; triage rather than blindly applying breaking upgrades.
- Uploads: test extension/MIME/signature mismatches, polyglots, active PDFs, oversized/empty files, traversal names, scan outage and quarantine authorization.
- Abuse controls/telemetry: validate external Auth/WAF settings, application budgets, `Retry-After`, privacy minimization, immutable events and alert thresholds.
