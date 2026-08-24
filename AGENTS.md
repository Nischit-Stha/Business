# Veera V2 Engineering Principles

These rules apply to all V2 work under `apps/`, `supabase/`, and related V2 documentation. The existing V1 prototype is reference material during migration and must not be modified or deleted unless a reviewed migration task explicitly requires it.

## Architecture and security

- Authorization is server-controlled. UI checks are usability aids, never security boundaries.
- Access is deny-by-default. PostgreSQL Row Level Security and server-side checks must explicitly grant the minimum required access.
- Operational state must not fall back to `localStorage`. Durable operational data belongs in PostgreSQL; private files will belong in private Supabase Storage.
- Supabase service-role keys, database passwords, access tokens, production credentials, and private customer documents must never enter client bundles or source control.
- Seeds, fixtures, logs, screenshots, and tests must contain synthetic data only—never real personally identifiable information (PII).

## Data and operations

- Every database change is delivered through a reviewed, forward-only migration in `supabase/migrations/`.
- Financial transaction history is immutable. Corrections use compensating entries rather than updates or deletes.
- Important state changes must be attributable and auditable, including actor, timestamp, action, and relevant before/after context.
- Multi-step business operations must be atomic and preserve invariants on failure or retry.
- Design routine workflows for automation and management by exception. Human attention is reserved for approvals, ambiguity, financial risk, negotiation, major vehicle issues, and genuine exceptions.

## Delivery

- Keep browser UI, server application/API logic, and persistence concerns separated.
- Add automated tests in proportion to risk and run `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build` before review.
- Do not connect development commands or migrations to production. Use local Supabase by default and a separately controlled staging project when explicitly approved.

