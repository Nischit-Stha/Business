# Veera V2 production readiness checklist

Veera V2 is **not production-ready**. This checklist deliberately separates implemented code from configuration, external verification and business approval.

## READY in the application

- [x] Deny-by-default staff/customer authorization and RLS tests
- [x] Immutable financial/audit histories and compensating payment corrections
- [x] Private document buckets, short signed access, file signature/size/path controls
- [x] Fixed authenticated scheduler registry with locking/idempotency/history
- [x] Provider fail-closed defaults and synthetic datasets/tests
- [x] Controlled RTO completion requiring stored-payment completion plus external confirmation

## NEEDS CONFIGURATION

- [ ] Isolated production Supabase/web projects, exact Auth redirects, custom domain and TLS
- [ ] Server-only secrets in managed secret storage with rotation ownership
- [ ] Mandatory admin MFA, enrolment/recovery flow, JWT/session and leaked-password policy
- [ ] WAF/gateway rate limits, CAPTCHA and abuse alerts
- [ ] CSP and reviewed security headers at the deployed edge
- [ ] Central privacy-approved logs/telemetry, uptime/error alerts and on-call ownership
- [ ] Scheduled caller, per-job alerts and stuck-job monitoring
- [ ] Automated backups, retention and a successful restore exercise

## NEEDS EXTERNAL PROVIDER

- [ ] Verified Resend/Supabase SMTP domain, webhook and synthetic staging certification
- [ ] Malware scanning/quarantine for uploaded files
- [ ] RENTA/STARR365 official API access and contracts, if Veera chooses to use them
- [ ] Bank/SMS/WhatsApp provider selection only after separate security/business review

## NEEDS BUSINESS APPROVAL

- [ ] Final agreement/payment wording and RTO/legal-transfer procedure
- [ ] PayID instructions/reference convention
- [ ] Notification templates, cadence, consent and complaint handling
- [ ] Privacy notice, access roles, retention/deletion and document handling
- [ ] Support, incident response, trial cohort and go/no-go owner

## NEEDS SECURITY REVIEW

- [ ] Independent RLS/IDOR/Storage review and non-destructive penetration test
- [ ] SAST, secret scanning and dependency policy in CI
- [ ] Webhook replay, scheduler boundary and rate-limit staging tests
- [ ] Manual accessibility testing with screen reader and keyboard

## BLOCKED

- [ ] Real-data migration until mapping, dry-run, reconciliation, privacy and rollback are approved
- [ ] Real customer UAT until isolated staging, email, monitoring and support are ready
- [ ] Production go-live until all HIGH/BLOCKER UAT items are closed and formal approval is recorded
