# Veera V2 demo guide

Use only the isolated trial environment and `supabase/seed.uat.sql`. Sign in with the documented synthetic E2E identities. Do not enter or display real customer or provider data.

## 10–15 minute path

1. **Owner dashboard (1 minute).** Start with the attention queue. Explain that Veera sees genuine exceptions instead of checking every customer and car.
2. **Today (1 minute).** Open `/today`; move directly to pickups, returns, overdue payments, blocked cars, approvals and reviews.
3. **Fleet (1 minute).** Filter ready/available, rented and workshop cars. Open a car to show rego, RWC, service and issue blockers.
4. **Customer and agreement (2 minutes).** Open a synthetic customer, readiness documents, assigned car and weekly agreement. For rent-to-own, show stored-term progress and the separate external ownership-transfer confirmation—Veera never invents legal terms or transfers ownership.
5. **Payments (2 minutes).** Show Due Today, Overdue, Upcoming and Paid; then open advanced reconciliation for the ambiguous synthetic receipt. Explain immutable receipts, allocation and compensating reversals.
6. **Maintenance and issue (1 minute).** Show upcoming service, the workshop car and the open warning-light issue with history and customer-safe status.
7. **Customer portal (2 minutes).** Sign in as Avery Example. Show My Car, payment status, next service, private documents and quick requests/reporting.
8. **Toll/fine (1 minute).** Open the synthetic review item, inspect custody evidence and explain that staff—not automation—confirm legal transfer.
9. **Automation (1 minute).** Show reviewed jobs, execution history, retries and repeated-failure attention. External sending remains disabled.
10. **Reports and owner queue (1 minute).** Show trustworthy totals, then return to owner attention to close the loop.

## Business story

- Time saved: routine schedules, reminders, custody matching and readiness are calculated consistently.
- Stress reduced: blocked allocations and meaningful exceptions are explicit.
- Scale enabled: the same workflow is exercised with 150–500 synthetic vehicles; no customer-specific spreadsheet logic is required.

Remote email delivery and managed scheduling must not be demonstrated as live until staging credentials, synthetic inboxes and alert ownership are approved.
