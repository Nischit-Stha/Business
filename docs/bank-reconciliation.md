# Staged bank reconciliation

This feature is a local/staging-only reconciliation boundary for synthetic PayID-style receipts. It does not connect to a bank, accept credentials, call a PayID API, or enable production banking-file import.

## Synthetic CSV format

The UTF-8 CSV header must be exactly:

```text
external_transaction_id,transaction_date,received_at,amount,description,payer_name_raw,reference_raw
```

`transaction_date` is an ISO date, `received_at` is an ISO-8601 timestamp with timezone, and `amount` is a positive decimal receipt. Imports are capped at 500 rows and 500 KB by the server action. Tests and fixtures must use synthetic identities and values. The UI previews five rows, while authoritative parsing and validation occur server-side.

## Idempotency and raw data

Each file has a SHA-256 checksum. Re-importing the same source/checksum returns the existing batch. `(source, external_transaction_id)` is also unique, so an external transaction cannot be imported twice across different files. Duplicate rows are reported without creating another transaction and generate one deduplicated exception per external ID.

Raw description, payer name, and reference values are retained on the imported record. They are not copied into audit metadata. Import and reconciliation history is never deleted.

## Matching rules

Matching v1 considers active or suspended agreements with outstanding schedule obligations. Its additive, deterministic evidence includes:

- exact total outstanding amount;
- a multiple of the expected weekly amount;
- an agreement UUID in the reference;
- exact normalized payer/customer name;
- a normalized customer phone in the reference;
- an outstanding obligation within 14 days either side of the transaction date.

All candidates scoring at least 20 are retained with their component evidence. A unique score of at least 85 is `HIGH` only when it also includes an exact outstanding amount and a strong identifier (agreement reference, phone, or exact name). Scores of at least 55 are `MEDIUM`; weaker candidates are `LOW`. Equal top scores are `AMBIGUOUS`, and no candidate is `NO_MATCH`.

Only `HIGH` can be auto-allocated. `MEDIUM`, `LOW`, `AMBIGUOUS`, and `NO_MATCH` remain `REVIEW_REQUIRED`. Ambiguous receipts are never silently posted.

## Allocation and manual review

Staff may confirm the suggestion, select another agreement, or split a receipt across up to three agreements in the current UI. Every manual action requires the authenticated active staff actor and a reason. The original match run and candidates remain immutable when staff override it.

Confirmed amounts create receipts through the existing immutable payment transaction model. Existing FIFO rules allocate oldest obligations first, including future obligations. Partial, exact, multi-week, and advance payments therefore behave the same as manually recorded payments. A unique bank-to-payment posting prevents the same bank receipt/agreement from posting twice, while the transaction-level check prevents a second reconciliation operation.

Any amount not assigned in a split remains visible as an unposted balance. Any amount assigned to an agreement but beyond its available schedule remains `payment_transactions.unallocated_amount`. Both generate an `UNRESOLVED_UNALLOCATED_AMOUNT` exception; money is never discarded. Reconciliation refreshes schedule state and cancels queued overdue reminders and staged deliveries once arrears clear.

## Ignore and reversal

Unposted receipts can be ignored only with an actor and reason. Allocated receipts cannot be ignored.

Reversal creates immutable compensating payment transactions and negative allocations through the existing reversal function. The imported receipt changes to `REVERSED`, but the original import, match evidence, postings, payments, and actions remain. A `BANK_REVERSAL_REVIEW` exception is raised because downstream chargeback handling can require judgment. A future bank-feed adapter should represent negative feed records with `reverses_imported_bank_transaction_id`, verify amount/currency/account semantics, and route unsafe cases to review rather than automatically reversing them.

## Exceptions and audit

Open operational exceptions use stable deduplication keys for unmatched receipts, ambiguous matches, suspicious duplicates, unusually large receipts (the staged threshold is AUD 1,000), unresolved balances, reversal review, and failed batches. Existing exception assignment/resolution controls apply.

Audit events cover batch creation, transaction import, matching, auto-allocation, manual overrides, allocation, ignore, reversal, and exception creation/resolution. Audit metadata contains identifiers, statuses, counts, scores, and amounts—not payer names, raw references, descriptions, phone numbers, or credentials.

## Security and production boundary

All reconciliation tables use RLS with active-staff read policies and no browser write grants. Mutations occur only through security-definer functions that repeat the active-staff check. Ledger evidence, actions, and postings are immutable. The upload action is server-only and identifies its sole source as `SYNTHETIC_CSV`.

Before any production bank feed is considered, implement and review a separate server-side adapter with secret management, provider authentication, signature verification, account/currency identity, pagination/cursors, replay handling, negative transaction semantics, monitoring, retention/privacy rules, and staging certification. Do not reuse the synthetic upload route for real files. No real customer or banking data belongs in source, tests, logs, screenshots, or seeds.
