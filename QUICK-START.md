# Quick Setup - 2 Steps to Activate Supabase

## ✅ Code is Ready - Just Need These 2 Things

---

## STEP 1: Create Storage Bucket (5 minutes)

### Go to Supabase Dashboard:
1. Click **Storage** (left sidebar)
2. Click **Create a new bucket**
3. Name: `customer-photos`
4. Click **Private** (important!)
5. Click **Create Bucket**

Done! ✅

---

## STEP 2: Apply RLS Policies (5 minutes)

### Go to Supabase Dashboard:
1. Click **SQL Editor** (left sidebar)
2. Click **New Query**
3. Open this file: `supabase-setup-final.sql`
4. Copy ALL the SQL
5. Paste into SQL Editor
6. Click **Run**
7. Wait for success message

Done! ✅

---

## STEP 3: Test It Works (2 minutes)

### Open website and test:
1. Go to your rentals site
2. Try to upload a photo in service/pickup form
3. Submit the form
4. Photo should upload to Supabase Storage
5. Check browser console for no errors

Done! ✅

---

## That's All!

Your app is now fully secure with:
- ✅ Photos in cloud storage (not in database)
- ✅ Role-based access control
- ✅ Customers see only their data
- ✅ Admin sees everything
- ✅ Automatic signed URLs for security

---

## Helpful Files

- **SUPABASE-SETUP-GUIDE.md** - Detailed step-by-step with screenshots
- **COMPLETION-SUMMARY.md** - Full overview of what was done
- **supabase-setup-final.sql** - All RLS policies to apply
- **rentals/service.html** - Updated with Storage upload code

---

## Common Issues?

**Q: Storage bucket not appearing?**
- Refresh page, try again
- Check Supabase is connected to your project

**Q: SQL won't run?**
- Copy the ENTIRE file (all 300+ lines)
- Check for red error text
- Contact Supabase support if stuck

**Q: Photos not uploading?**
- Check console for errors (F12)
- Verify bucket is named exactly `customer-photos`
- Check bucket is set to PRIVATE

---

## Success Indicators

When it's working, you'll see:
- ✅ Photos upload without Base64 in database
- ✅ Database rows much smaller
- ✅ Customers only see their own data
- ✅ Admin can see everything
- ✅ No console errors

---

**Status:** Ready to go! Just run Step 1 & 2 above.

Questions? Check the detailed guides in the repo.
