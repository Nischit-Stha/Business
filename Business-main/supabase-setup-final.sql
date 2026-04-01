-- ============================================================================
-- SUPABASE STORAGE & RLS SETUP - FINAL CONFIGURATION
-- ============================================================================
-- This SQL sets up:
-- 1. Storage bucket for customer photos with RLS policies
-- 2. Role-based RLS policies for all data tables
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE STORAGE BUCKET FOR PHOTOS
-- ============================================================================
-- Run this in Supabase SQL Editor, or use Supabase Dashboard:
-- 1. Go to Storage > Buckets
-- 2. Create new bucket: "customer-photos"
-- 3. Make it PUBLIC
-- 4. Add RLS policies below

-- The bucket name is: customer-photos
-- It will store: /pickup-photos/{rental_id}/*.jpg, /dropoff-photos/{rental_id}/*.jpg, etc.

-- ============================================================================
-- STEP 2: RLS POLICIES FOR STORAGE BUCKET (if using SQL)
-- ============================================================================
-- Enable RLS on the storage.objects table:
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customers_upload_own_photos" ON storage.objects;
DROP POLICY IF EXISTS "customers_view_own_photos" ON storage.objects;
DROP POLICY IF EXISTS "admins_full_access_photos" ON storage.objects;

-- Policy: Allow app users (anon/authenticated) to upload photos
CREATE POLICY "customers_upload_own_photos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'customer-photos'
  AND (auth.role() = 'anon' OR auth.uid() IS NOT NULL)
);

-- Policy: Allow app users (anon/authenticated) to read photo objects
CREATE POLICY "customers_view_own_photos"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'customer-photos'
  AND (auth.role() = 'anon' OR auth.uid() IS NOT NULL)
);

-- Policy: Allow admins full access
CREATE POLICY "admins_full_access_photos"
ON storage.objects
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================================
-- STEP 3: STRICT RLS POLICIES FOR DATA TABLES
-- ============================================================================
-- These policies enforce role-based access control

-- ===== VEHICLES TABLE =====
-- Admin can do everything, customers can only view available vehicles
DROP POLICY IF EXISTS "customers_view_available_vehicles" ON vehicles;
DROP POLICY IF EXISTS "admins_full_vehicle_access" ON vehicles;

CREATE POLICY "customers_view_available_vehicles"
ON vehicles
FOR SELECT
USING (status = 'available' OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY "admins_full_vehicle_access"
ON vehicles
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ===== BOOKING_REQUESTS TABLE =====
-- Customers see only their own, admins see all
DROP POLICY IF EXISTS "customers_see_own_bookings" ON booking_requests;
DROP POLICY IF EXISTS "customers_create_bookings" ON booking_requests;
DROP POLICY IF EXISTS "admins_full_booking_access" ON booking_requests;

CREATE POLICY "customers_see_own_bookings"
ON booking_requests
FOR SELECT
USING (
  customer_id = auth.uid()
  OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "customers_create_bookings"
ON booking_requests
FOR INSERT
WITH CHECK (customer_id = auth.uid());

CREATE POLICY "customers_update_own_bookings"
ON booking_requests
FOR UPDATE
USING (customer_id = auth.uid())
WITH CHECK (customer_id = auth.uid());

CREATE POLICY "admins_full_booking_access"
ON booking_requests
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ===== OFFERS TABLE =====
-- Customers see offers on their bookings, admins see all
DROP POLICY IF EXISTS "customers_see_own_offers" ON offers;
DROP POLICY IF EXISTS "admins_full_offer_access" ON offers;

CREATE POLICY "customers_see_own_offers"
ON offers
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM booking_requests 
    WHERE booking_requests.id = offers.booking_request_id 
    AND booking_requests.customer_id = auth.uid()
  )
  OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "admins_full_offer_access"
ON offers
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ===== OFFER_MESSAGES TABLE =====
-- Customers see messages on their offers, admins see all
DROP POLICY IF EXISTS "customers_see_own_offer_messages" ON offer_messages;
DROP POLICY IF EXISTS "customers_create_offer_messages" ON offer_messages;
DROP POLICY IF EXISTS "admins_full_offer_message_access" ON offer_messages;

CREATE POLICY "customers_see_own_offer_messages"
ON offer_messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM offers 
    WHERE offers.id = offer_messages.offer_id
    AND EXISTS (
      SELECT 1 FROM booking_requests
      WHERE booking_requests.id = offers.booking_request_id
      AND booking_requests.customer_id = auth.uid()
    )
  )
  OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "customers_create_offer_messages"
ON offer_messages
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM offers
    WHERE offers.id = offer_messages.offer_id
    AND EXISTS (
      SELECT 1 FROM booking_requests
      WHERE booking_requests.id = offers.booking_request_id
      AND booking_requests.customer_id = auth.uid()
    )
  )
);

CREATE POLICY "admins_full_offer_message_access"
ON offer_messages
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ===== PAYMENT_INTENTS TABLE =====
-- Customers see only their payments, admins see all
DROP POLICY IF EXISTS "customers_see_own_payments" ON payment_intents;
DROP POLICY IF EXISTS "admins_full_payment_access" ON payment_intents;

CREATE POLICY "customers_see_own_payments"
ON payment_intents
FOR SELECT
USING (
  user_id = auth.uid()
  OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "admins_full_payment_access"
ON payment_intents
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ===== INVOICES TABLE =====
-- Customers see only their invoices, admins see all
DROP POLICY IF EXISTS "customers_see_own_invoices" ON invoices;
DROP POLICY IF EXISTS "admins_full_invoice_access" ON invoices;

CREATE POLICY "customers_see_own_invoices"
ON invoices
FOR SELECT
USING (
  customer_id = auth.uid()
  OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "admins_full_invoice_access"
ON invoices
FOR ALL
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================================
-- STEP 4: VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify RLS is working:

-- Check if admin exists
-- SELECT id, email, role FROM profiles WHERE role = 'admin';

-- Check if storage bucket exists
-- SELECT name, owner FROM storage.buckets WHERE name = 'customer-photos';

-- Check RLS is enabled on tables
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = true;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. Storage bucket "customer-photos" must be created via Supabase Dashboard (set to PUBLIC for direct image URLs)
-- 2. All policies assume customer_id or user_id matches auth.uid()
-- 3. Admin profile must exist with role = 'admin'
-- 4. RLS must be ENABLED on all tables (ALTER TABLE ... ENABLE ROW LEVEL SECURITY)
-- 5. Test policies in browser console before going live
