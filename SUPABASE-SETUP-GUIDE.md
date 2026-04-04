# Supabase Setup - Final Manual Steps

This guide is for the current app architecture in this repo.

## What I fixed in code

- Replaced setup SQL with a working, re-runnable script:
  - `supabase-setup-final.sql`
- Script now:
  - Creates/updates storage bucket `customer-photos`
  - Enables RLS on required tables
  - Drops old conflicting policies safely
  - Applies app-compatible policies so current frontend works
  - Includes verification queries

## Manual steps you still need to do (required)

### 1. Run SQL in Supabase

1. Open Supabase dashboard for your project
2. Go to **SQL Editor**
3. Open file `supabase-setup-final.sql`
4. Paste all content into a new query
5. Run it

Note: If you previously saw `must be owner of table objects`, this is expected on some projects. The updated SQL avoids storage table ownership operations.

### 2. Verify the script results

In the same SQL editor, run the verification queries at the bottom of `supabase-setup-final.sql`.

You should confirm:
- Bucket `customer-photos` exists
- `public` is `true` for that bucket
- RLS is enabled on required public tables
- Policies exist for storage and all required tables

### 3. Add Storage policies in Dashboard (manual)

Because `storage.objects` may be ownership-restricted in SQL editor, create storage policies in dashboard:

1. Go to **Storage -> Policies**
2. Select bucket: `customer-photos`
3. Add 4 policies for roles `anon, authenticated`:
  - INSERT allowed when `bucket_id = 'customer-photos'`
  - SELECT allowed when `bucket_id = 'customer-photos'`
  - UPDATE allowed when `bucket_id = 'customer-photos'`
  - DELETE allowed when `bucket_id = 'customer-photos'`

### 4. Test from the app

1. Open pickup page:
   - `rentals/frontend/service.html?type=pickup`
2. Submit one pickup service
3. Open admin bookings page:
   - `rentals/frontend/admin.html`
4. Confirm one new row appears in Bookings

## Troubleshooting

### If pickup submit still fails

- Open browser console on the service page and check for `Supabase booking request save failed`
- Confirm `booking_requests` table exists and has columns used by app:
  - `id, customer, phone, email, car, vehicle_id, pickup_at, return_at, notes, status, source, created_at`

### If photo upload fails

- Confirm bucket name is exactly `customer-photos`
- Confirm bucket is public
- Confirm storage policies for `storage.objects` were created by SQL

### If admin page shows no data

- Ensure policy `booking_requests_app_access` exists
- Ensure row was actually inserted (check `booking_requests` table in Supabase)

## Important security note

Current policies are intentionally app-compatible for your existing no-login flow. They allow anon/authenticated access so integration works now.

If you later migrate to strict user auth (Supabase Auth), tighten policies to per-user access using `auth.uid()`.
