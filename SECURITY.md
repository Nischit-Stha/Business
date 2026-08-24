# Security Policy

## Current Risk Profile

This project is an MVP and requires additional hardening before production use.

## Roles

- `anon`: public customer traffic with minimal permissions
- `authenticated`: signed-in users
- `admin`: privileged operators (enforced via DB policy and token claims)

## Mandatory Rules

- Never expose service-role keys in frontend code.
- Keep frontend with publishable/anon keys only.
- Enforce admin authorization in database policies or backend functions.
- Keep license photo bucket private and access-controlled.
- Use deny-by-default RLS, then allow only required operations.

## Supabase Setup

- MVP/dev compatibility script: `supabase-setup-final.sql`
- Production hardening script: `supabase-security-hardening.sql`

Apply production hardening only after auth and admin-role claims are configured.

## RLS Test Matrix

Test each table with:

1. `anon` user
2. normal `authenticated` user
3. `admin` user

Validate that:

- `anon` cannot read sensitive customer/license data.
- only `admin` can read/update invoices, customers, fleet-wide data.
- booking submission allows only intended insert paths.

## Vulnerability Handling

- Rotate exposed credentials immediately.
- Review logs and revoke affected tokens/keys.
- Patch in a dedicated security branch and release with rollback notes.
