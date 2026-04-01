# Supabase Setup - Complete Implementation Guide

## Current Status: 3/5 Tasks Completed

### ✅ Completed
1. **Supabase Storage bucket SQL** - Ready to apply
2. **Photo upload to Storage** - Code updated in service.html
3. **URL storage instead of Base64** - Implemented

### ⏳ Remaining
4. **Apply role-based RLS policies** - SQL ready, need to execute
5. **Validate policies work** - Testing needed

---

## Step-by-Step Implementation

### Phase 1: Create Storage Bucket (Dashboard)

**Go to Supabase Dashboard:**
1. Click **Storage** in left sidebar
2. Click **Create a new bucket**
3. Name: `customer-photos`
4. Make it **PRIVATE** (not public)
5. Click Create

**That's it!** The app will automatically upload photos to this bucket.

---

### Phase 2: Apply RLS Policies (SQL)

**File to use:** `/supabase-setup-final.sql`

**Where to run:**
1. Go to Supabase Dashboard → **SQL Editor**
2. Click **New Query**
3. Copy-paste the SQL from the file
4. Run it

**What it does:**
- Creates storage bucket policies (allow customer uploads)
- Creates strict RLS on all data tables
- Customers see ONLY their own data
- Admin sees EVERYTHING

**Important:** Run this AFTER creating the storage bucket above.

---

### Phase 3: Test the Policies

**In Browser Console:**

```javascript
// Test 1: Check if admin profile exists
// Go to rentals/frontend/index.html and open browser console
// Run this:
const client = window.getVeeraSupabaseClient();
const { data: admin, error } = await client
  .from('profiles')
  .select('*')
  .eq('role', 'admin')
  .single();
console.log('Admin exists:', admin || 'NOT FOUND');

// Test 2: Try to access other customer's booking
// (Should be blocked by RLS)
const { data: others, error: err } = await client
  .from('booking_requests')
  .select('*')
  .neq('customer_id', (await client.auth.getSession()).user.id);
console.log('Got others bookings:', others?.length || 0, 'Error:', err);
// ^ Should have error or 0 results (RLS blocked it)
```

---

## How It Works Now

### Photo Upload Flow:
1. Customer uploads photo via service.html
2. Photo gets uploaded to `customer-photos` bucket in Supabase Storage
3. Storage returns URL (e.g., `https://xxx.supabase.co/storage/v1/object/...`)
4. URL gets saved in database (much smaller than Base64!)
5. Admin can view all photos via signed URLs

### Data Access Flow:
1. Customer logs in with Supabase Auth
2. RLS policies check their `auth.uid()`
3. They can only see/edit their own bookings, offers, payments
4. Admin can see everything

---

## Files Modified

- **rentals/service.html** - Updated to upload photos to Storage
- **supabase-setup-final.sql** - All RLS policies ready to apply

---

## What to Do Next

1. **Create storage bucket** via Dashboard
2. **Run SQL** to apply RLS policies
3. **Test** in browser console
4. **Verify** that:
   - Photos upload successfully
   - Customers can't see others' data
   - Admin can see everything

---

## Important Notes

- **Storage bucket name must be exactly:** `customer-photos`
- **All tables MUST have RLS enabled** (already done in previous SQL)
- **Policies reference the `profiles` table** - make sure admin profile exists
- **Signed URLs are automatic** - customers can't hack URLs to see others' photos
- **Fallback to localStorage** still works if Supabase is down

---

## Security Features

✅ **Role-based access** - customers vs admin  
✅ **Row-level security** - can't see others' data  
✅ **File upload restrictions** - can only upload to own folder  
✅ **Signed URLs** - can't guess/access others' photos  
✅ **Auth-linked** - tied to Supabase user accounts  

---

## Troubleshooting

**Photos not uploading?**
- Check Storage bucket is created and named `customer-photos`
- Check browser console for errors
- Verify Supabase client is connected

**Can't access RLS SQL?**
- Make sure you're logged into Supabase as project admin
- Go to Settings → Database → Edit to check RLS is enabled on tables

**Still seeing Base64 in database?**
- Old records will have Base64 (that's OK)
- New records will have URLs (correct)
- Over time, old data will phase out

---

## Command Reference

**Check if bucket exists:**
```sql
SELECT name FROM storage.buckets WHERE name = 'customer-photos';
```

**Check RLS is enabled:**
```sql
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' AND rowsecurity = true;
```

**See storage policies:**
```sql
SELECT * FROM pg_policies 
WHERE tablname ~ 'objects';
```

---

Done! Follow steps above to complete Supabase setup.
