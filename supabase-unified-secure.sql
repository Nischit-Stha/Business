-- =============================================================================
-- SUPABASE UNIFIED SECURE SETUP (MERGED)
-- =============================================================================
-- Merges:
--   1) supabase-setup-final.sql
--   2) supabase-security-hardening.sql
--   3) supabase-rls-fixes.sql
--
-- Goal:
--   - One script you can run end-to-end
--   - Idempotent (safe to re-run)
--   - Production-oriented security baseline
--
-- Notes:
--   - This enforces strict RLS for admin-managed data.
--   - Public (anon) can submit booking requests only.
--   - Storage bucket is private and admin-only by default.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) BUCKET BASELINE (private by default)
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('customer-photos', 'customer-photos', false)
ON CONFLICT (id)
DO UPDATE SET public = EXCLUDED.public;

-- -----------------------------------------------------------------------------
-- 2) CORE TABLES
-- -----------------------------------------------------------------------------
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
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

CREATE TABLE IF NOT EXISTS public.vehicles (
  id BIGSERIAL PRIMARY KEY,
  name TEXT,
  make TEXT,
  model TEXT,
  plate TEXT,
  status TEXT NOT NULL DEFAULT 'available',
  rate_day NUMERIC NOT NULL DEFAULT 80,
  rate_week NUMERIC NOT NULL DEFAULT 250,
  location TEXT NOT NULL DEFAULT 'Main Branch',
  images JSONB NOT NULL DEFAULT '[]'::jsonb,
  availability JSONB NOT NULL DEFAULT '[]'::jsonb,
  color TEXT,
  mileage INTEGER NOT NULL DEFAULT 0,
  fuel TEXT,
  vin TEXT,
  import_meta JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

CREATE TABLE IF NOT EXISTS public.booking_requests (
  id BIGSERIAL PRIMARY KEY,
  customer TEXT,
  customer_id BIGINT,
  phone TEXT,
  email TEXT,
  car TEXT,
  vehicle_id BIGINT,
  pickup_at TIMESTAMPTZ,
  return_at TIMESTAMPTZ,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'submitted',
  source TEXT,
  request_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

CREATE TABLE IF NOT EXISTS public.offers (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT,
  customer_name TEXT,
  customer_email TEXT,
  customer_phone TEXT,
  vehicle_id BIGINT,
  car_name TEXT,
  car_model TEXT,
  listed_rate NUMERIC NOT NULL DEFAULT 0,
  offered_rate NUMERIC NOT NULL DEFAULT 0,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  owner_response TEXT,
  counter_rate NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

CREATE TABLE IF NOT EXISTS public.offer_messages (
  id BIGSERIAL PRIMARY KEY,
  offer_id BIGINT NOT NULL,
  sender_role TEXT NOT NULL DEFAULT 'customer',
  message TEXT NOT NULL DEFAULT '',
  message_type TEXT NOT NULL DEFAULT 'message',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

CREATE TABLE IF NOT EXISTS public.payment_intents (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT,
  invoice_id BIGINT,
  amount NUMERIC NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'AUD',
  status TEXT NOT NULL DEFAULT 'pending',
  provider TEXT,
  provider_reference TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

CREATE TABLE IF NOT EXISTS public.invoices (
  id BIGSERIAL PRIMARY KEY,
  rental_id BIGINT,
  invoice_no TEXT,
  customer TEXT,
  customer_id BIGINT,
  customer_phone TEXT,
  customer_email TEXT,
  car_id BIGINT,
  car_name TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  issue_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  due_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pickup_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  return_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  total_days NUMERIC NOT NULL DEFAULT 0,
  daily_rate NUMERIC NOT NULL DEFAULT 0,
  sub_total NUMERIC NOT NULL DEFAULT 0,
  tax_rate NUMERIC NOT NULL DEFAULT 0,
  tax_amount NUMERIC NOT NULL DEFAULT 0,
  total_amount NUMERIC NOT NULL DEFAULT 0,
  paid_amount NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  last_modified_by UUID
);

-- -----------------------------------------------------------------------------
-- 3) MIGRATION-SAFE COLUMN UPGRADES
-- -----------------------------------------------------------------------------
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS current_vehicle TEXT,
  ADD COLUMN IF NOT EXISTS last_request_type TEXT,
  ADD COLUMN IF NOT EXISTS license_photo_urls JSONB,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS last_booking_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS make TEXT,
  ADD COLUMN IF NOT EXISTS model TEXT,
  ADD COLUMN IF NOT EXISTS plate TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS rate_day NUMERIC,
  ADD COLUMN IF NOT EXISTS rate_week NUMERIC,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS images JSONB,
  ADD COLUMN IF NOT EXISTS availability JSONB,
  ADD COLUMN IF NOT EXISTS color TEXT,
  ADD COLUMN IF NOT EXISTS mileage INTEGER,
  ADD COLUMN IF NOT EXISTS fuel TEXT,
  ADD COLUMN IF NOT EXISTS vin TEXT,
  ADD COLUMN IF NOT EXISTS import_meta JSONB,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS customer TEXT,
  ADD COLUMN IF NOT EXISTS customer_id BIGINT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS car TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_id BIGINT,
  ADD COLUMN IF NOT EXISTS pickup_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS return_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS source TEXT,
  ADD COLUMN IF NOT EXISTS request_type TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

ALTER TABLE public.offers
  ADD COLUMN IF NOT EXISTS customer_id BIGINT,
  ADD COLUMN IF NOT EXISTS customer_name TEXT,
  ADD COLUMN IF NOT EXISTS customer_email TEXT,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_id BIGINT,
  ADD COLUMN IF NOT EXISTS car_name TEXT,
  ADD COLUMN IF NOT EXISTS car_model TEXT,
  ADD COLUMN IF NOT EXISTS listed_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS offered_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS note TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS owner_response TEXT,
  ADD COLUMN IF NOT EXISTS counter_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

ALTER TABLE public.offer_messages
  ADD COLUMN IF NOT EXISTS offer_id BIGINT,
  ADD COLUMN IF NOT EXISTS sender_role TEXT,
  ADD COLUMN IF NOT EXISTS message TEXT,
  ADD COLUMN IF NOT EXISTS message_type TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

ALTER TABLE public.payment_intents
  ADD COLUMN IF NOT EXISTS customer_id BIGINT,
  ADD COLUMN IF NOT EXISTS invoice_id BIGINT,
  ADD COLUMN IF NOT EXISTS amount NUMERIC,
  ADD COLUMN IF NOT EXISTS currency TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS provider TEXT,
  ADD COLUMN IF NOT EXISTS provider_reference TEXT,
  ADD COLUMN IF NOT EXISTS metadata JSONB,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS rental_id BIGINT,
  ADD COLUMN IF NOT EXISTS invoice_no TEXT,
  ADD COLUMN IF NOT EXISTS customer TEXT,
  ADD COLUMN IF NOT EXISTS customer_id BIGINT,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT,
  ADD COLUMN IF NOT EXISTS customer_email TEXT,
  ADD COLUMN IF NOT EXISTS car_id BIGINT,
  ADD COLUMN IF NOT EXISTS car_name TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS issue_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS pickup_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS return_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS total_days NUMERIC,
  ADD COLUMN IF NOT EXISTS daily_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS sub_total NUMERIC,
  ADD COLUMN IF NOT EXISTS tax_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS tax_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS total_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS paid_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS last_modified_by UUID;

-- -----------------------------------------------------------------------------
-- 4) DEFAULTS + CONSTRAINTS
-- -----------------------------------------------------------------------------
ALTER TABLE public.customers
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW();

ALTER TABLE public.vehicles
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW();

ALTER TABLE public.booking_requests
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW(),
  ALTER COLUMN status SET DEFAULT 'submitted';

ALTER TABLE public.invoices
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW();

ALTER TABLE public.offers
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW();

ALTER TABLE public.payment_intents
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW();

-- Normalize legacy values so stricter CHECK constraints can be introduced safely.
UPDATE public.booking_requests
SET status = CASE
  WHEN status IS NULL OR BTRIM(status) = '' THEN 'submitted'
  WHEN LOWER(BTRIM(status)) IN ('submitted', 'pending', 'new', 'requested', 'request', 'open') THEN 'submitted'
  WHEN LOWER(BTRIM(status)) IN ('under_review', 'under review', 'review', 'processing', 'in_progress', 'in progress') THEN 'under_review'
  WHEN LOWER(BTRIM(status)) IN ('approved', 'accept', 'accepted', 'confirmed') THEN 'approved'
  WHEN LOWER(BTRIM(status)) IN ('completed', 'complete', 'closed', 'returned', 'done') THEN 'completed'
  WHEN LOWER(BTRIM(status)) IN ('rejected', 'reject', 'declined', 'cancelled', 'canceled') THEN 'rejected'
  ELSE 'under_review'
END;

UPDATE public.booking_requests
SET request_type = CASE
  WHEN request_type IS NULL OR BTRIM(request_type) = '' THEN NULL
  WHEN LOWER(BTRIM(request_type)) IN ('pickup', 'pick up', 'pick-up', 'checkin', 'check-in') THEN 'pickup'
  WHEN LOWER(BTRIM(request_type)) IN ('dropoff', 'drop off', 'drop-off', 'checkout', 'check-out', 'return') THEN 'dropoff'
  WHEN LOWER(BTRIM(request_type)) IN ('swap', 'exchange', 'change') THEN 'swap'
  ELSE NULL
END;

UPDATE public.vehicles
SET status = CASE
  WHEN status IS NULL OR BTRIM(status) = '' THEN 'available'
  WHEN LOWER(BTRIM(status)) IN ('available', 'free', 'ready') THEN 'available'
  WHEN LOWER(BTRIM(status)) IN ('rented', 'rent', 'onrent', 'on-rent', 'active') THEN 'rented'
  WHEN LOWER(BTRIM(status)) IN ('maintenance', 'service', 'repair', 'workshop') THEN 'maintenance'
  ELSE 'maintenance'
END;

DO $$
BEGIN
  ALTER TABLE public.booking_requests
    ADD CONSTRAINT booking_requests_status_check
    CHECK (status IN ('submitted', 'under_review', 'approved', 'completed', 'rejected'))
    NOT VALID;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.booking_requests
    ADD CONSTRAINT booking_requests_request_type_check
    CHECK (request_type IN ('pickup', 'dropoff', 'swap'))
    NOT VALID;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.vehicles
    ADD CONSTRAINT vehicles_status_check
    CHECK (status IN ('available', 'rented', 'maintenance'))
    NOT VALID;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.booking_requests
    ADD CONSTRAINT booking_requests_customer_identifier_check
    CHECK (
      COALESCE(NULLIF(TRIM(phone), ''), NULLIF(TRIM(email), ''), CASE WHEN customer_id IS NOT NULL THEN 'id' ELSE NULL END) IS NOT NULL
    )
    NOT VALID;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- -----------------------------------------------------------------------------
-- 5) FOREIGN KEYS + INDEXES
-- -----------------------------------------------------------------------------
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

CREATE INDEX IF NOT EXISTS customers_email_idx ON public.customers (email);
CREATE INDEX IF NOT EXISTS customers_phone_idx ON public.customers (phone);
CREATE INDEX IF NOT EXISTS customers_last_booking_at_idx ON public.customers (last_booking_at DESC);
CREATE INDEX IF NOT EXISTS customers_email_lookup_idx ON public.customers (LOWER(email));
CREATE INDEX IF NOT EXISTS customers_phone_lookup_idx ON public.customers (phone);

CREATE INDEX IF NOT EXISTS vehicles_plate_idx ON public.vehicles (plate);
CREATE INDEX IF NOT EXISTS vehicles_status_idx ON public.vehicles (status);
CREATE INDEX IF NOT EXISTS vehicles_rego_lookup_idx ON public.vehicles (plate);

CREATE INDEX IF NOT EXISTS booking_requests_vehicle_id_idx ON public.booking_requests (vehicle_id);
CREATE INDEX IF NOT EXISTS booking_requests_customer_id_idx ON public.booking_requests (customer_id);
CREATE INDEX IF NOT EXISTS booking_requests_created_at_idx ON public.booking_requests (created_at DESC);
CREATE INDEX IF NOT EXISTS booking_requests_status_idx ON public.booking_requests (status);
CREATE INDEX IF NOT EXISTS booking_requests_request_type_idx ON public.booking_requests (request_type);

CREATE INDEX IF NOT EXISTS offers_vehicle_id_idx ON public.offers (vehicle_id);
CREATE INDEX IF NOT EXISTS offers_customer_id_idx ON public.offers (customer_id);
CREATE INDEX IF NOT EXISTS offer_messages_offer_id_idx ON public.offer_messages (offer_id);

CREATE INDEX IF NOT EXISTS invoices_invoice_no_idx ON public.invoices (invoice_no);
CREATE INDEX IF NOT EXISTS invoices_customer_id_idx ON public.invoices (customer_id);
CREATE INDEX IF NOT EXISTS invoices_created_at_idx ON public.invoices (created_at DESC);

CREATE INDEX IF NOT EXISTS payment_intents_invoice_id_idx ON public.payment_intents (invoice_id);
CREATE INDEX IF NOT EXISTS payment_intents_customer_id_idx ON public.payment_intents (customer_id);

-- -----------------------------------------------------------------------------
-- 6) AUDIT FUNCTIONS + TRIGGERS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_audit_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_at := COALESCE(NEW.created_at, NOW());
    NEW.created_by := COALESCE(NEW.created_by, auth.uid());
  END IF;

  NEW.updated_at := NOW();
  NEW.last_modified_by := auth.uid();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_audit_customers ON public.customers;
CREATE TRIGGER set_audit_customers
BEFORE INSERT OR UPDATE ON public.customers
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_audit_vehicles ON public.vehicles;
CREATE TRIGGER set_audit_vehicles
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_audit_booking_requests ON public.booking_requests;
CREATE TRIGGER set_audit_booking_requests
BEFORE INSERT OR UPDATE ON public.booking_requests
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_audit_invoices ON public.invoices;
CREATE TRIGGER set_audit_invoices
BEFORE INSERT OR UPDATE ON public.invoices
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_audit_offers ON public.offers;
CREATE TRIGGER set_audit_offers
BEFORE INSERT OR UPDATE ON public.offers
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_audit_offer_messages ON public.offer_messages;
CREATE TRIGGER set_audit_offer_messages
BEFORE INSERT OR UPDATE ON public.offer_messages
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

DROP TRIGGER IF EXISTS set_audit_payment_intents ON public.payment_intents;
CREATE TRIGGER set_audit_payment_intents
BEFORE INSERT OR UPDATE ON public.payment_intents
FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- -----------------------------------------------------------------------------
-- 7) ADMIN HELPER
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    FALSE
  );
$$;

-- -----------------------------------------------------------------------------
-- 8) ENABLE RLS + RESET POLICIES
-- -----------------------------------------------------------------------------
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offer_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('customers','vehicles','booking_requests','offers','offer_messages','payment_intents','invoices')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 9) TABLE POLICIES (STRICT + USEFUL)
-- -----------------------------------------------------------------------------
-- Admin full access for core management tables
CREATE POLICY customers_admin_only
ON public.customers
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY vehicles_admin_only
ON public.vehicles
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY offers_admin_only
ON public.offers
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY offer_messages_admin_only
ON public.offer_messages
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY payment_intents_admin_only
ON public.payment_intents
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY invoices_admin_only
ON public.invoices
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Booking requests:
-- - admin full control
-- - anon can submit new requests only (public intake form)
CREATE POLICY booking_requests_admin_full
ON public.booking_requests
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY booking_requests_public_submit
ON public.booking_requests
FOR INSERT
TO anon
WITH CHECK (
  status = 'submitted'
  AND (
    request_type IN ('pickup', 'dropoff', 'swap')
    OR request_type IS NULL
  )
  AND (
    NULLIF(TRIM(phone), '') IS NOT NULL
    OR NULLIF(TRIM(email), '') IS NOT NULL
    OR customer_id IS NOT NULL
  )
);

-- -----------------------------------------------------------------------------
-- 10) STORAGE POLICIES (private, admin-only)
-- -----------------------------------------------------------------------------
CREATE POLICY storage_customer_photos_admin_read
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'customer-photos' AND public.is_admin());

CREATE POLICY storage_customer_photos_admin_write
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'customer-photos' AND public.is_admin());

CREATE POLICY storage_customer_photos_admin_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'customer-photos' AND public.is_admin())
WITH CHECK (bucket_id = 'customer-photos' AND public.is_admin());

CREATE POLICY storage_customer_photos_admin_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'customer-photos' AND public.is_admin());

COMMIT;

-- =============================================================================
-- QUICK VERIFICATION QUERIES
-- =============================================================================
-- SELECT id, name, public FROM storage.buckets WHERE id = 'customer-photos';
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname='public' AND tablename IN ('customers','vehicles','booking_requests','offers','offer_messages','payment_intents','invoices');
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname IN ('public','storage') ORDER BY schemaname, tablename, policyname;
