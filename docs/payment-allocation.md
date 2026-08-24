# Veera V2 manual payment allocation

This workflow records PayID payments only after staff have independently verified receipt. It does not contact a bank, collect money, or reconcile PayID automatically.

## Allocation rules

1. A positive receipt is written once to the immutable `payment_transactions` ledger.
2. The receipt is allocated to that agreement's non-waived obligations in ascending `due_date`, then `sequence_number` order.
3. The oldest obligation is filled before allocation continues to the next obligation.
4. The same rule handles exact, partial, multi-week, and advance payments. Future obligations are eligible after earlier obligations are filled.
5. Money beyond the currently generated schedule remains on the receipt as `unallocated_amount`; it is never discarded or silently moved.
6. Allocations are immutable. A correction creates a negative reversal transaction and matching negative allocation entries. The original receipt and allocations remain intact.
7. A reversal restores the affected obligation balances but does not retrospectively reallocate later receipts. Any resulting allocation exception remains visible for staff review.

Schedule generation is idempotent through unique agreement/sequence and agreement/due-date constraints. Open-ended agreements generate through a default 26-week horizon and can be extended safely with `generate_payment_schedule`.

Payment status shown in reporting is evaluated against the current date. An obligation is overdue when its due date is before today, it is not waived, and its paid amount is below its due amount.
