# External integration readiness

All adapters are disabled and fail closed. Veera must continue to operate through manual signed-agreement upload, synthetic CSV reconciliation and staff-reviewed toll/fine workflows when no provider is available.

## RENTA questions for the vendor

- Is there an official supported API and staging tenant? Obtain base URLs, authentication/rotation, scopes and IP requirements.
- Which contract fields and agreement types are supported? Can metadata be updated after signature?
- What are the idempotency, versioning, rate-limit and retry rules?
- How are signature invitations sent, and what consent/template controls apply?
- Are signing-status webhooks signed/replay-protected? How are signed PDFs/checksums retrieved?
- What are retention, deletion, audit, data-residency, incident and support commitments?

The typed boundary covers create/update contract, send for signature, status and signed-PDF retrieval with external document references. No endpoint is assumed.

## STARR365 information required

- Official API/staging access, authentication, scopes, supported vehicle/customer lookups and stable external identifiers.
- Toll/fine schema, pagination/cursors, correction/duplicate semantics and custody timestamps/time zones.
- Supported transfer-status lifecycle and whether Veera may only observe or may submit a status.
- Webhook signatures, rate limits, retention, audit, data residency and vendor support.

No screen scraping or live-account browser automation is permitted. The boundary covers lookup, import, transfer status and external references.

## Bank feed security requirements

The provider-neutral interface represents external transaction ID, event/receipt timestamps, decimal amount/currency, description/reference, reversal link and cursor. Before implementation require read-only least-privilege access, account/currency binding, strong secret storage/rotation, mTLS/OAuth as applicable, cursor/replay rules, signed webhooks, availability/rate limits, privacy retention, monitoring and staging certification. Negative/reversal records must never silently mutate Veera’s immutable ledger.

Synthetic CSV remains a supported fallback. No bank or PayID credential belongs in Veera source, browser code, logs or test data.
