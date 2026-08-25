# Operational automation sprint

## Scheduled runner

`scheduled_jobs` is a fixed registry of reviewed operations. `run_due_scheduled_jobs` selects due rows with row locking and bounded limits; `run_scheduled_job` adds per-job leases and idempotency keys. Each job is isolated so a failure does not stop another due job. Execution history becomes immutable after its single `RUNNING` to terminal transition.

The runner is local/staging only. It is not connected to production cron, queues, notification providers, webhooks, Starr365, or government systems. A future deployment may call the due-runner RPC from controlled infrastructure without changing the job contract.

## Notification completion

Payment receipts now queue through a transaction trigger, including bank reconciliations that post through the existing controlled payment function. Pre-due stages are held separately from due/overdue stages to avoid ambiguous signs. Delivery attempts contain only provider identity, safe result/category, bounded message id, and duration. Raw provider responses and credentials are excluded.

The internal receipt RPC exists for local/testing `SENT → DELIVERED` transitions. Issue status automation is opt-in and renders only the public status; issue descriptions and staff notes are not included.

## Operational read models

The customer summary, vehicle detail, movement readiness, issue work queue, and notification attention views are staff-only through security-invoker access to RLS-protected tables. They omit contact details, addresses, document paths, licence images/numbers, raw bank data, and provider/debug payloads.

## Production gaps

- Select and configure production scheduling infrastructure with service identity, monitoring, timeouts, and incident response.
- Implement real provider adapters, signed delivery receipts/webhooks, provider reconciliation, and secret rotation.
- Validate throughput and pagination against staging-scale data.
- Review notification policy, customer consent, and issue-status wording before enabling automation broadly.
- Keep Starr365 and government transfer integration behind the separately documented provider-neutral boundary.
