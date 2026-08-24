# Strict Bug-Check Checklist (Rentals App)

Use this as a line-by-line review sheet before releases and after major logic changes.

## How to Use

- Mark each item as `PASS` or `FAIL`.
- If `FAIL`, record the exact page, action, and expected behavior.
- Do not ship if any critical security/data-integrity item fails.

---

## 1) Validation (Blocker)

### Required fields
- [ ] Name cannot be empty and trims whitespace-only input.
- [ ] Phone is normalized before lookup/storage.
- [ ] Email is validated when provided (or explicitly optional by flow).
- [ ] Rego format is standardized (same casing/pattern everywhere).
- [ ] Mileage rejects negative values.
- [ ] Mileage rejects unrealistic values.
- [ ] Budget is numeric if required by flow.
- [ ] Request type only accepts valid values.

### Upload validation
- [ ] Pickup requires license photos.
- [ ] Drop-off requires return photos if workflow requires them.
- [ ] Swap requires required return/transfer photos if workflow requires them.
- [ ] File type is restricted (expected image MIME types only).
- [ ] File size limit is enforced.
- [ ] Invalid files fail with clear user message.

### Input edge cases
- [ ] Empty strings do not bypass validation.
- [ ] Very long values are rejected or safely constrained.
- [ ] Special characters do not break rendering/storage.

---

## 2) Request Status Rules (Blocker)

### Valid transitions only
- [ ] `submitted -> under_review` allowed.
- [ ] `under_review -> approved` allowed.
- [ ] `approved -> completed` allowed.
- [ ] `submitted/under_review -> rejected` allowed when needed.
- [ ] Invalid jumps (e.g., `submitted -> completed`) are blocked.

### Closed-state behavior
- [ ] Rejected requests are not treated as active bookings.
- [ ] Completed requests are read-only unless explicit override exists.
- [ ] Status changes are reflected consistently across all admin views.

---

## 3) Customer Linking Logic (Blocker)

### Matching and dedupe
- [ ] Customer matching works predictably by normalized phone.
- [ ] Customer matching works predictably by normalized email.
- [ ] Customer matching behavior by rego is defined and consistent.
- [ ] Same person is not duplicated due to formatting differences.

### Safe updates
- [ ] Request updates do not overwrite the wrong customer profile.
- [ ] `current_vehicle` reflects latest valid operational state.
- [ ] `last_request_type` updates correctly for pickup/drop-off/swap.

---

## 4) Fleet Availability Logic (Blocker)

### Assignment correctness
- [ ] Vehicle cannot be assigned to two active requests.
- [ ] Vehicle marked unavailable while actively assigned.
- [ ] Drop-off releases vehicle only after completion is confirmed.
- [ ] Swap updates old vehicle and new vehicle states correctly.

### Consistency checks
- [ ] Fleet counts match request/customer state.
- [ ] Availability in UI matches database truth after reload.

---

## 5) Admin Authorization + RLS (Blocker)

### Route/UI checks are not enough
- [ ] Direct URL access to admin pages without proper auth is blocked.
- [ ] Hidden UI controls are not relied on for security.

### Backend policy enforcement
- [ ] Admin read/write is enforced via Auth + RLS/backend logic.
- [ ] Customers cannot query admin-only data via request tampering.
- [ ] Session-expired admin actions fail safely with clear message.

### Supabase security coverage
- [ ] RLS enabled on all exposed tables.
- [ ] Policies exist for required `select/insert/update/delete` operations.
- [ ] Admin policies separated from anon/customer policies.
- [ ] No service-role/bypass key appears in frontend code.
- [ ] License photo storage is private and policy-protected.

---

## 6) Data Integrity + Schema Checks

- [ ] Foreign keys prevent broken request/customer/vehicle references.
- [ ] Required fields are enforced in schema (not only UI).
- [ ] Indexes exist for phone/email/rego/status/customer lookups.
- [ ] Insert/update operations fail clearly when constraints fail.

---

## 7) Error Handling (High Priority)

- [ ] Network/Supabase failures are shown clearly to user/admin.
- [ ] Missing photo upload produces explicit error.
- [ ] Duplicate customer match conflict is handled predictably.
- [ ] Rego-not-found produces actionable feedback.
- [ ] Empty admin tables render safely (no broken UI).
- [ ] DB write success + UI render failure is detected/logged.
- [ ] Partial form submissions cannot silently create corrupt records.

---

## 8) Critical Integration Flows (Automated + Manual)

### Integration tests to add/keep
- [ ] Pickup flow end-to-end.
- [ ] Drop-off flow end-to-end.
- [ ] Swap flow end-to-end.
- [ ] Admin approval/review flow.
- [ ] Fleet availability update regression flow.
- [ ] RLS role-context tests (`anon`, `customer`, `admin`).

### Unit tests to add/keep
- [ ] Validation helper tests.
- [ ] Status transition rule tests.
- [ ] Customer merge/match tests.

---

## 9) Manual End-to-End Review Script

Run in this order and log result for each:

1. [ ] Submit pickup with valid data.
2. [ ] Submit pickup with missing required fields and verify rejection.
3. [ ] Verify admin sees correct request type and linked customer/vehicle.
4. [ ] Verify fleet state changes after approval/completion.
5. [ ] Attempt double-booking same vehicle and verify block.
6. [ ] Complete drop-off and verify booking closes cleanly.
7. [ ] Execute swap and verify both vehicles update correctly.
8. [ ] Validate photo upload/store/retrieve permissions.
9. [ ] Attempt unauthorized admin data access and verify denial.
10. [ ] Reload pages and verify DB-consistent state.

---

## 10) Hidden-Bug Probe List

- [ ] Duplicate customers from phone-format variation.
- [ ] Drop-off linked to wrong rego/customer.
- [ ] Swap leaves old vehicle active.
- [ ] Admin table stale data after mutation.
- [ ] Success toast shown despite failed DB write.
- [ ] Request stored without required photos.
- [ ] Customer profile accidentally overwritten by later request.
- [ ] Availability changed visually but not persisted.
- [ ] RLS policy over-broad read access.

---

## Recommended Improvement Order

1. Validation
2. Status/business rules
3. Customer and vehicle linking
4. Auth and RLS enforcement
5. Automated tests
6. UX edge-case improvements

---

## Review Result Summary

- Date:
- Reviewer:
- Build/Commit:
- Critical failures:
- High-priority failures:
- Release decision: `GO / NO-GO`
