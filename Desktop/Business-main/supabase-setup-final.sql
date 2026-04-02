-- ============================================================================
-- SUPABASE SETUP (WORKING WITH CURRENT FRONTEND ARCHITECTURE)
-- ============================================================================
-- This project currently uses the public anon key and does not require users to
-- sign in with Supabase Auth before creating bookings.
--
-- This script configures RLS so the current frontend works end-to-end:
-- - service pickup submit inserts into booking_requests
-- - admin pages can read/update rows
-- - photos upload/read from storage bucket customer-photos
--
-- Run this entire script in Supabase SQL Editor.
-- ============================================================================

-- ============================================================================
-- STEP 1: STORAGE BUCKET
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('customer-photos', 'customer-photos', true)
ON CONFLICT (id)
DO UPDATE SET public = EXCLUDED.public;

-- ============================================================================
-- STEP 2: ENABLE RLS
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customers (
  id BIGSERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  current_vehicle TEXT,
  last_request_type TEXT,
  license_photo_urls JSONB,
  notes TEXT,
  last_booking_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS customers_email_idx ON public.customers (email);
CREATE INDEX IF NOT EXISTS customers_phone_idx ON public.customers (phone);
CREATE INDEX IF NOT EXISTS customers_last_booking_at_idx ON public.customers (last_booking_at DESC);

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offer_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS customer_id BIGINT;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS customer_id BIGINT;

DO $$
BEGIN
  ALTER TABLE public.booking_requests
    ADD CONSTRAINT booking_requests_customer_id_fkey
    FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.invoices
    ADD CONSTRAINT invoices_customer_id_fkey
    FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- STEP 3: RESET EXISTING POLICIES (SAFE RE-RUN)
-- ============================================================================
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'vehicles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.vehicles', r.policyname);
  END LOOP;

  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'customers'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.customers', r.policyname);
  END LOOP;

  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'booking_requests'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.booking_requests', r.policyname);
  END LOOP;

  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'offers'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.offers', r.policyname);
  END LOOP;

  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'offer_messages'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.offer_messages', r.policyname);
  END LOOP;

  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'payment_intents'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.payment_intents', r.policyname);
  END LOOP;

  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'invoices'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.invoices', r.policyname);
  END LOOP;
END $$;

-- ============================================================================
-- STEP 4: STORAGE POLICIES (MANUAL IN DASHBOARD)
-- ============================================================================
-- If your SQL role is not owner of storage.objects, run storage policies from:
-- Supabase Dashboard -> Storage -> Policies (bucket: customer-photos)
-- Create policies equivalent to:
-- 1) INSERT: bucket_id = 'customer-photos' for anon, authenticated
-- 2) SELECT: bucket_id = 'customer-photos' for anon, authenticated
-- 3) UPDATE: bucket_id = 'customer-photos' for anon, authenticated
-- 4) DELETE: bucket_id = 'customer-photos' for anon, authenticated

-- ============================================================================
-- STEP 5: TABLE POLICIES (APP-COMPATIBLE)
-- ============================================================================
-- Note: These policies allow anon/authenticated frontend access so the app works
-- without Supabase Auth sign-in. If you later migrate to full auth, tighten these.

CREATE POLICY "vehicles_app_access"
ON public.vehicles
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "customers_app_access"
ON public.customers
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "booking_requests_app_access"
ON public.booking_requests
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "offers_app_access"
ON public.offers
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "offer_messages_app_access"
ON public.offer_messages
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "payment_intents_app_access"
ON public.payment_intents
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "invoices_app_access"
ON public.invoices
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 6: VERIFICATION QUERIES
-- ============================================================================
-- 1) Bucket exists and is public
SELECT id, name, public FROM storage.buckets WHERE id = 'customer-photos';

-- 2) RLS enabled on required tables
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('customers', 'vehicles', 'booking_requests', 'offers', 'offer_messages', 'payment_intents', 'invoices');

-- 3) Policies created
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE (schemaname = 'storage' AND tablename = 'objects')
  OR (schemaname = 'public' AND tablename IN ('customers', 'vehicles', 'booking_requests', 'offers', 'offer_messages', 'payment_intents', 'invoices'))
ORDER BY schemaname, tablename, policyname;
