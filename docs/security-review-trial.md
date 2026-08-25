# Trial security review

Reviewed 2026-08-25. Scope: V2 Next.js server components/actions/routes, Supabase migrations/RLS/Storage, notification and scheduler boundaries. This is an engineering review, not an independent penetration test.

## Fixed in this sprint

- Critical: no unauthenticated scheduler endpoint; POST requires a timing-safe 32+ character bearer secret and the database wrapper accepts only service role plus a configured active admin actor.
- High: account provisioning is admin-only and server-side; service role never enters browser code. Disable revokes all sessions and blocks both the Veera account link and Supabase Auth user.
- High: invitation/recovery tokens remain in Supabase Auth and are never stored/logged. Invitation metadata, expiry, resend and acceptance are audited.
- High: external providers are blocked in trial/development unless explicitly opted in. Resend responses are reduced to safe categories; verified Svix webhooks drive DELIVERED.
- High: private uploads retain size, magic-byte MIME, randomized/path-safe object names, private buckets, authorization RPCs, audited 60-second signed URLs and no-cache metadata.
- Medium: sensitive account actions require MFA AAL2 when present or a session issued within ten minutes. Other sessions are revoked after password changes.
- Medium: public account recovery has an enumeration-neutral response. Public registration remains disabled.
- Medium: an environment/test-data banner and admin status view reduce staging/production confusion.

## Remaining findings

- High: require MFA for all production administrators in Supabase policy and add a complete enrolment/recovery-code UI before production. Current architecture reads AAL but trial enrolment remains an Auth/dashboard procedure.
- High: add edge/WAF rate limiting and CAPTCHA for login/recovery, webhook and scheduler endpoints. Supabase Auth limits are necessary but application/gateway limits should be tested.
- High: obtain an independent RLS/IDOR and Storage penetration test before production; pgTAP and E2E cover known boundaries but are not adversarial assurance.
- Medium: server actions rely on secure SameSite cookies, Next.js origin checks and framework action identifiers. Add an explicit deployment allowed-origin policy and test proxy/header behavior.
- Medium: the scheduler SQL timeout is a five-minute outer cap; enforce each `scheduled_jobs.timeout_seconds` independently if jobs move to separate worker transactions.
- Medium: define privacy-approved security telemetry and retention before production. Audit deliberately omits IP/user-agent.
- Medium: add malware scanning/quarantine before files become staff-viewable; file-signature validation is not antivirus.
- Medium: formalize lockfile audit, update automation, SAST and secret scanning in CI. Local `npm audit` is only a point-in-time check.
- Low: add Content-Security-Policy and security-header verification at the deployment edge after confirming Supabase/Storage origins.

No evidence was found of browser service-role exposure, operational `localStorage`, public Storage buckets, raw path input in object keys, an open redirect in the new callback, direct customer-ID trust in portal actions, or raw provider response bodies entering the database.
