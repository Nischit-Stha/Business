# Veera Rentals V2 architecture

## Business goal

Veera Rentals operates roughly 150 vehicles and needs to grow without owner workload, staff workload, and operational stress increasing at the same rate. V2 will make routine work deterministic and automatable, surface exceptions early, and reserve human attention for approvals, ambiguity, financial risk, customer negotiation, major vehicle issues, and genuine exceptions.

This foundation task establishes the delivery architecture only. It intentionally does not implement business workflows, a rental schema, external integrations, or production migration.

## Proposed system architecture

V2 is an npm workspace with the application in `apps/web` and database lifecycle files in `supabase`.

- **Web application:** Next.js App Router and strict TypeScript provide the staff interface and server-rendered application entry points.
- **Application/API boundary:** Next.js route handlers, server actions, and server-only modules own trusted orchestration. Browsers do not make authorization decisions or hold privileged credentials.
- **Identity:** Supabase Auth will authenticate staff. Authorization will be evaluated server-side and reinforced by deny-by-default PostgreSQL Row Level Security (RLS).
- **Persistence:** Supabase PostgreSQL is the system of record. Every database change is represented by an ordered migration.
- **Files:** A later task will place sensitive documents in private Supabase Storage with short-lived, authorized access. No public document buckets are part of this foundation.
- **Automation:** Later domain services and workers will execute idempotent, observable business operations. They will generate exception work items when a safe automatic outcome is unavailable.

The server boundary may use the staff user's Supabase session where RLS is the correct enforcement point. Any future privileged operation must remain server-only, perform its own authorization, minimize service-role use, and write the required audit record atomically with the change.

## V1 versus V2 boundary

The existing root static pages, `rentals/`, legacy SQL files, imports, and related documentation are V1. They remain unchanged and available only as migration reference. V2 code lives in `apps/web`; V2 database configuration and forward migrations live in `supabase/`.

V1 claims, client-side role checks, browser storage, and direct table access are not security or architecture precedents for V2. Capabilities will move domain by domain only after their V2 data model, authorization policy, audit behavior, tests, and rollback approach have been reviewed. V1 deletion is a separate, explicit end-of-migration decision.

## Major domains

The expected domain boundaries are listed for planning, not implemented by this task:

- staff identity, roles, and approvals
- customers, identity evidence, consent, and risk
- fleet, vehicle availability, condition, and maintenance
- enquiries, quotes, negotiations, bookings, and rental lifecycle
- handover, return, extensions, swaps, incidents, fines, and tolls
- pricing, bonds, payments, invoices, refunds, and immutable ledger activity
- communications, tasks, automation runs, exceptions, and audit history
- reporting and operational controls

Domain ownership should be explicit. Cross-domain workflows belong in server-side application services and must be atomic where one business outcome spans multiple records.

## Development workflow

Requirements are Node.js 22.13+ (CI uses Node.js 22), npm, Docker, and the Supabase CLI. Typical commands are:

```sh
npm install
npm run dev
npm run lint
npm run typecheck
npm test
npm run build
```

For local database work, use the repository-pinned CLI through `npm run supabase:start` and `npm run supabase:reset`. `supabase:reset` recreates the local database, applies every migration in order, and runs `supabase/seed.sql`. Developers must inspect their CLI target before any command capable of affecting a remote project. This repository is not to be linked to production.

Configuration begins with `.env.example`. Copy it to an ignored `.env.local` and use the local values printed by `supabase status`. Production values belong in an approved secret manager and deployment environment, never in GitHub workflow files or source control.

Pull requests must keep changes scoped, add appropriate tests, and pass dependency installation, lint, typecheck, tests, and production build in CI. Database pull requests include the migration and policy tests relevant to the change.

## Migration strategy

1. Inventory one V1 capability and define its V2 ownership, invariants, exception states, and acceptance criteria.
2. Add a forward-only migration with least-privilege grants and deny-by-default RLS. Never edit an already-applied migration to change deployed behavior.
3. Add server-side application logic, audit behavior, idempotency protections, and automated tests.
4. Validate with synthetic data in local Supabase, then in a separately controlled staging project.
5. Reconcile a dry-run extract before any approved production cutover. Migration scripts must be repeatable, observable, and preserve source identifiers for reconciliation without exposing them to clients.
6. Move traffic in a reversible, domain-by-domain release. Monitor exceptions and reconcile counts and financial totals.
7. Retire the corresponding V1 path only after acceptance and an explicit review. Keep V1 as reference until the overall migration is complete.

Real customer data is outside this foundation task. No production Supabase project is connected or modified.

## Security principles

- Authenticate staff with Supabase Auth; authorize every trusted action on the server and in database policy where applicable.
- Deny access by default and grant only the minimum table, row, column, function, and storage permissions required.
- Treat client input, client state, token metadata editable by users, and V1 browser checks as untrusted.
- Never expose service-role keys to the browser. Never commit keys, passwords, access tokens, production credentials, real PII, or driver licence documents.
- Store operational state in PostgreSQL, not `localStorage`; store future sensitive files only in private buckets.
- Keep financial transactions immutable and correct errors with linked compensating entries.
- Record important changes with actor, time, reason, source, and relevant before/after context.
- Use database transactions and constraints for atomic business operations; add idempotency for retries and external events.
- Use synthetic seeds and fixtures. Minimize production data access and redact sensitive values from logs and telemetry.
- Automate only when rules can produce a safe result; otherwise stop, preserve context, and create a clear exception for staff.
