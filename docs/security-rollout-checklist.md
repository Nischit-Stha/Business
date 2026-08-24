# Security Rollout Checklist

This is the exact order to run the database hardening + import safely.

## 1) Apply unified security schema
Run in Supabase SQL Editor:
- `supabase-unified-secure.sql`

## 2) Import cleaned weekly data
Run in Supabase SQL Editor:
- `imports/current_file_to_supabase.sql`

## 3) Validate constraints and policies
Run in Supabase SQL Editor:
- `supabase-validation-checks.sql`

## 4) Set admin role in Supabase Auth
For your admin user, ensure one of these is set:
- `app_metadata.role = "admin"`
- or `user_metadata.role = "admin"`

## 5) Verify frontend auth behavior
- Login with admin user should access dashboard.
- Login with non-admin user should be denied.
- `rentals/frontend/login.html` and `rentals/frontend/index.html` now use role checks only.

## 6) Expected security outcomes
- `customer-photos` bucket is private.
- Management tables are admin-only via RLS.
- `booking_requests` allows public `INSERT` only (with required minimal data).
- Legacy status/request_type values normalized and constrained.

## 7) If validation fails
Use these triage checks:
```sql
SELECT id, status, request_type, phone, email, customer_id
FROM public.booking_requests
WHERE status NOT IN ('submitted','under_review','approved','completed','rejected')
   OR (request_type IS NOT NULL AND request_type NOT IN ('pickup','dropoff','swap'))
   OR COALESCE(NULLIF(TRIM(phone), ''), NULLIF(TRIM(email), ''), CASE WHEN customer_id IS NOT NULL THEN 'id' ELSE NULL END) IS NULL
LIMIT 100;
```
