-- =============================================================================
-- SUPABASE POST-DEPLOY VALIDATION CHECKS
-- Run this after `supabase-unified-secure.sql`
-- =============================================================================

-- 1) Ensure constraints are fully validated (old + new rows)
ALTER TABLE public.booking_requests VALIDATE CONSTRAINT booking_requests_status_check;
ALTER TABLE public.booking_requests VALIDATE CONSTRAINT booking_requests_request_type_check;
ALTER TABLE public.booking_requests VALIDATE CONSTRAINT booking_requests_customer_identifier_check;
ALTER TABLE public.vehicles VALIDATE CONSTRAINT vehicles_status_check;

-- 2) Table + RLS status
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('customers','vehicles','booking_requests','offers','offer_messages','payment_intents','invoices','weekly_collection_ledger')
ORDER BY tablename;

-- 3) Policy inventory
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname IN ('public', 'storage')
ORDER BY schemaname, tablename, policyname;

-- 4) Bucket privacy check
SELECT id, name, public
FROM storage.buckets
WHERE id = 'customer-photos';

-- 5) Data quality checks for booking_requests
SELECT 'invalid_status' AS issue, COUNT(*) AS rows
FROM public.booking_requests
WHERE status NOT IN ('submitted','under_review','approved','completed','rejected')
UNION ALL
SELECT 'invalid_request_type', COUNT(*)
FROM public.booking_requests
WHERE request_type IS NOT NULL
  AND request_type NOT IN ('pickup','dropoff','swap')
UNION ALL
SELECT 'missing_customer_identifier', COUNT(*)
FROM public.booking_requests
WHERE COALESCE(NULLIF(TRIM(phone), ''), NULLIF(TRIM(email), ''), CASE WHEN customer_id IS NOT NULL THEN 'id' ELSE NULL END) IS NULL;

-- 6) Quick snapshot counts
SELECT
  (SELECT COUNT(*) FROM public.customers) AS customers_count,
  (SELECT COUNT(*) FROM public.vehicles) AS vehicles_count,
  (SELECT COUNT(*) FROM public.booking_requests) AS booking_requests_count,
  (SELECT COUNT(*) FROM public.offers) AS offers_count,
  (SELECT COUNT(*) FROM public.offer_messages) AS offer_messages_count,
  (SELECT COUNT(*) FROM public.payment_intents) AS payment_intents_count,
  (SELECT COUNT(*) FROM public.invoices) AS invoices_count,
  (SELECT COUNT(*) FROM public.weekly_collection_ledger) AS weekly_collection_ledger_count;
