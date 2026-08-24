# Fix This First: Prioritized Checklist

**Last Updated:** April 19, 2026  
**Priority:** CRITICAL — Complete in order before production or external review  
**Owner:** Veera Rental System Development Team

---

## Overview

This checklist identifies **logic, validation, authorization, and data integrity** issues that typically cause hidden bugs in business apps. Follow the order below; each section must be verified before moving to the next.

**Fix Order:**
1. Validation (all form inputs)
2. Request status rules (pickup/drop-off/swap logic)
3. Customer and vehicle linking (deduplication, rego lookup)
4. Admin authorization (RLS testing, role enforcement)
5. Error handling (DB failures, network issues, expired sessions)
6. Automated tests (unit + integration)
7. CI/CD and monitoring

---

## SECTION 1: VALIDATION — STRICT INPUT CHECKS

**Status:** ⚠️ PARTIALLY COMPLETE  
**References:** `rentals/frontend/validation/request-validation.js`, `rentals/frontend/service.html`

### 1.1 Name Validation
- [ ] Reject blank or whitespace-only input (`"   "` should fail)
- [ ] Reject names with only numbers or special characters
- [ ] Trim whitespace before save and lookup
- [ ] Test with:
  - Valid: `"John Doe"`, `"Ali O'Brien"`, `"Maria García"`
  - Invalid: `""`, `"   "`, `"123"`, `"!!!"`
- **File:** `rentals/frontend/validation/request-validation.js` → `isValidName()`
- **Test:** Open service.html, submit pickup with blank name → should show error alert

### 1.2 Phone Validation
- [ ] Normalize phone before save (remove spaces, dashes, parentheses)
- [ ] Normalize phone before lookup (so `0412 345 678` = `0412345678`)
- [ ] Validate format (AU: 10 digits starting with `04`, US: 10 digits, etc.)
- [ ] Reject blank or less than 8 digits
- [ ] Test with:
  - Valid: `"0412345678"`, `"04 1234 5678"`, `"(041) 234 5678"`
  - Invalid: `""`, `"123"`, `"abc"`, `"99999"`
- **File:** `rentals/frontend/validation/request-validation.js` → `isValidPhone()`
- **After Save:** Check `customers.phone` in Supabase — should be normalized format

### 1.3 Email Validation
- [ ] Normalize email to lowercase before save
- [ ] Normalize email to lowercase before lookup (so `Ali@Gmail.com` = `ali@gmail.com`)
- [ ] Validate format (basic: must contain `@` and `.`)
- [ ] Reject blank, `@` without domain, domain without TLD
- [ ] Test with:
  - Valid: `"ali@example.com"`, `"Ali@EXAMPLE.COM"` (should normalize)
  - Invalid: `""`, `"ali"`, `"ali@"`, `"@example.com"`, `"ali.example.com"`
- **File:** `rentals/frontend/validation/request-validation.js` → `isValidEmail()`
- **After Save:** Check `customers.email` in Supabase — should be lowercase

### 1.4 Rego Validation
- [ ] Enforce one format rule everywhere (e.g., uppercase, no spaces: `"ABC123"`)
- [ ] Normalize rego before save (remove spaces, uppercase)
- [ ] Normalize rego before lookup (so `"abc 123"` = `"ABC123"`)
- [ ] Reject blank, too short (<3), or invalid characters
- [ ] Test with:
  - Valid: `"ABC123"`, `"abc 123"` (should normalize to `"ABC123"`)
  - Invalid: `""`, `"AB"`, `"ABC!@#"`, `"123ABC123ABC"`
- **File:** `rentals/frontend/validation/request-validation.js` → `isValidRego()`
- **After Save:** Check `vehicles.rego` in Supabase — all uppercase, no spaces

### 1.5 Mileage Validation
- [ ] Must be numeric (no text or special characters)
- [ ] Must be non-negative (reject `-1`, `-100`, etc.)
- [ ] Must be realistic (e.g., reject `999999999`, which is unlikely for rental fleet)
- [ ] Accept `0` for new vehicles
- [ ] Test with:
  - Valid: `"0"`, `"12345"`, `"150000"`
  - Invalid: `""`, `"-100"`, `"abc"`, `"12.34.56"`, `"999999999"`
- **File:** `rentals/frontend/validation/request-validation.js` → `isValidMileage()`

### 1.6 Budget Validation
- [ ] If budget is required in form, validate it is numeric and positive
- [ ] Reject blank, negative, text, or special characters
- [ ] Test with:
  - Valid: `"100"`, `"500.50"`
  - Invalid: `""`, `"-50"`, `"abc"`, `"500$"`
- **File:** `rentals/frontend/validation/request-validation.js` → add `isValidBudget()` if missing

### 1.7 Request Type Validation
- [ ] Only accept allowed values: `"pickup"`, `"drop-off"`, `"swap"`
- [ ] Reject any other value (e.g., `"delete"`, `"admin"`, `"UPDATE"`)
- [ ] Test with:
  - Valid: `"pickup"`, `"drop-off"`, `"swap"`
  - Invalid: `""`, `"PICKUP"`, `"pickup-now"`, `"admin"`, `"DROP OFF"` (space instead of dash)
- **File:** `rentals/frontend/validation/request-validation.js` → `isValidRequestType()`

### 1.8 Photo Validation
- [ ] Pickup requires at least 1 license photo
- [ ] Drop-off requires at least 1 return evidence photo (if workflow requires it)
- [ ] Swap requires both release and pickup photos
- [ ] Check file type (only `.jpg`, `.jpeg`, `.png`)
- [ ] Check file size (max 5MB per photo, reject larger)
- [ ] Reject if file extension doesn't match MIME type (e.g., `.jpg` file is actually `.png`)
- [ ] Test with:
  - Valid: Real `.jpg`/`.png` files under 5MB
  - Invalid: `.pdf`, `.txt`, `.gif`, 10MB file, mismatched extensions
- **File:** `rentals/frontend/service.html` → form submission handler

### 1.9 All Form Fields Pass Validation Before Submit
- [ ] Edit `rentals/frontend/service.html` form submission handler
- [ ] Before calling `saveCustomerToSupabase()` or DB functions:
  - Collect all form field values
  - Call `window.VeeraValidation.validateServicePayload()`
  - If `result.valid === false`, show each error in `result.errors` array
  - Block form submission with alert
- [ ] Example flow:
  ```javascript
  document.getElementById('submit-btn').addEventListener('click', async () => {
    const payload = {
      name: document.getElementById('name').value,
      phone: document.getElementById('phone').value,
      email: document.getElementById('email').value,
      rego: document.getElementById('rego').value,
      mileage: document.getElementById('mileage').value,
      request_type: document.getElementById('request-type').value,
      photos: /* collected from file input */
    };
    const validation = window.VeeraValidation.validateServicePayload(payload);
    if (!validation.valid) {
      alert('Validation errors:\n' + validation.errors.join('\n'));
      return; // Block submit
    }
    // Safe to proceed with save
    await saveCustomerToSupabase(payload);
  });
  ```
- **Test:** Try submitting service.html with each invalid input → should block and show error

---

## SECTION 2: REQUEST STATUS RULES — LOGIC CONSISTENCY

**Status:** ⚠️ NOT STARTED  
**Risk:** Swap might behave like drop-off; completed requests might remain active; rejected requests might block availability

### 2.1 Pickup Creates Correct Request Type
- [ ] Submit pickup form → `booking_requests` table entry has `request_type = "pickup"`
- [ ] Verify in Supabase: View `booking_requests` → all pickup records have `request_type` = `"pickup"`, never `"drop-off"` or `"swap"`
- [ ] Check `rental_status` = `"pending"` or `"approved"` (not `"completed"`)
- **Test File:** `rentals/frontend/service.html` (pickup section)

### 2.2 Drop-off Creates Correct Request Type
- [ ] Submit drop-off form → `booking_requests` table entry has `request_type = "drop-off"`
- [ ] Verify: No drop-off request should have `request_type = "pickup"` or `"swap"`
- [ ] Check `rental_status` = `"return_pending"` or `"completed"`
- **Test File:** `rentals/frontend/service.html` (drop-off section)

### 2.3 Swap Creates Correct Request Type and Links Both Vehicles
- [ ] Submit swap form → creates `booking_requests` entry with `request_type = "swap"`
- [ ] Swap must NOT behave like a normal drop-off (should release old vehicle AND assign new one in same transaction)
- [ ] Verify two vehicle state changes:
  - Old vehicle: `current_assignment = NULL`, `status = "available"`
  - New vehicle: `current_assignment = <new_request_id>`, `status = "assigned"`
- [ ] Check in Supabase: `vehicles` table → both rows updated
- **Test File:** `rentals/frontend/service.html` (swap section)

### 2.4 Completed Request Cannot Remain Active
- [ ] When `rental_status` transitions to `"completed"`:
  - [ ] Vehicle should release (if not already released)
  - [ ] Customer should show request as inactive
  - [ ] Admin dashboard should not list it in "active requests"
- [ ] Verify: Filter `booking_requests` by `rental_status = "completed"` and `request_type = "drop-off"` → should not appear in active list
- **Test:** Mark a request as completed → verify it disappears from active rental list

### 2.5 Rejected Requests Do Not Affect Availability
- [ ] Create a request and mark it `rental_status = "rejected"`
- [ ] Verify:
  - Vehicle is still `status = "available"` (not locked)
  - Customer profile does not show rejected request as active
  - Fleet tab counts exclude rejected requests
- **Test:** Check vehicles table → rejected request rows should not block vehicle availability

### 2.6 Page Refresh Shows Correct Database State, Not Stale Frontend State
- [ ] Load service.html → submit a pickup request
- [ ] Immediately refresh page (Ctrl+R or Cmd+R)
- [ ] Verify:
  - Customer data reloads from Supabase (name, phone, email)
  - Vehicle state reloads from Supabase (rego, current_assignment, status)
  - Request history shows new request (not blank because state wasn't persisted)
- [ ] In `admin.html`: Edit a request status, refresh → admin page should show updated status, not old cached value
- **Test Files:** `rentals/frontend/service.html`, `rentals/frontend/admin.html`

### 2.7 Double-Click Submit Does Not Create Duplicate Records
- [ ] Load service.html → quickly click submit button twice before page responds
- [ ] Verify: Only ONE `booking_requests` entry created, not two
- [ ] Check `customers` table → only one customer record (not duplicated)
- [ ] Check `vehicles` table → only one assignment (not duplicated)
- **Implementation Option:**
  - Disable submit button immediately after first click: `submitBtn.disabled = true`
  - Or add request deduplication check: if `saveCustomerToSupabase()` is called twice within 1 second with same phone + rego, use first result
- **Test:** Rapidly double-click or triple-click submit in service.html → should create only 1 record

---

## SECTION 3: CUSTOMER AND VEHICLE LINKING — DEDUPLICATION & CONSISTENCY

**Status:** ⚠️ PARTIALLY COMPLETE  
**Risk:** Duplicate customers, wrong rego lookup, stale profile data

### 3.1 Prevent Duplicate Customers (Phone Format)
- [ ] Phone normalization must happen BEFORE lookup, not after
- [ ] If customer with phone `"0412345678"` exists and new submission has `"04 1234 5678"`:
  - [ ] Lookup function normalizes both to `"0412345678"`
  - [ ] Returns existing customer record (does NOT create new record)
- [ ] Check in `rentals/frontend/app.js` or `rentals/frontend/service.html`:
  - Look for `findCustomerByPhone()` function
  - It should normalize input before query: `phone = phone.replace(/[- ()]/g, '')`
- **Test:** 
  - Submit pickup with phone `"0412 345 678"`
  - Submit another pickup with phone `"0412345678"` (same person, different format)
  - Verify only 1 customer record exists, not 2

### 3.2 Prevent Duplicate Customers (Email Case Differences)
- [ ] Email normalization must happen BEFORE lookup
- [ ] If customer with email `"Ali@Example.com"` exists and new submission has `"ali@example.com"`:
  - [ ] Lookup function normalizes both to lowercase
  - [ ] Returns existing customer record
- [ ] Check lookup function: should do `email = email.toLowerCase()`
- **Test:**
  - Submit pickup with email `"Ali@EXAMPLE.COM"`
  - Submit another pickup with email `"ali@example.com"`
  - Verify only 1 customer record exists

### 3.3 Rego Lookup Links Correct Booking and Customer
- [ ] When customer submits rego:
  - [ ] System normalizes rego (e.g., `"abc 123"` → `"ABC123"`)
  - [ ] Queries `vehicles` table for matching rego
  - [ ] Returns correct vehicle record and any active assignment
- [ ] Check `rentals/frontend/app.js` or similar:
  - Look for `findVehicleByRego()` function
  - Should normalize rego before query: `rego = rego.toUpperCase().replace(/ /g, '')`
- [ ] Verify:
  - Correct vehicle is linked to booking
  - Wrong vehicle is never linked (even if partial rego match)
- **Test:**
  - Create vehicle with rego `"ABC123"`
  - Submit request with rego `"abc 123"` (different format, same vehicle)
  - Verify correct vehicle is linked, no duplicates created

### 3.4 Editing Request Does Not Overwrite Wrong Customer Profile
- [ ] When admin edits a request (e.g., change customer name or phone):
  - [ ] Original customer profile should NOT be overwritten automatically
  - [ ] Either: create linked history record, or require explicit customer update
  - [ ] If customer profile is updated, it should only update the correct customer, not unrelated customers with similar names
- [ ] Check `rentals/frontend/admin.html`:
  - Look for request edit/update functions
  - Ensure they use customer ID (primary key), not name or phone lookup
- **Test:**
  - Create 2 customers: `"Ali Ahmed"` and `"Alison Adams"`
  - Edit booking of customer `"Ali Ahmed"` to change name to `"Alice Ahmed"`
  - Verify: Only `"Ali Ahmed"` record is updated, not `"Alison Adams"`

### 3.5 Current Vehicle Updates Only When Request Approved/Completed
- [ ] Customer profile field `current_vehicle` should be set ONLY when booking is `rental_status = "approved"` or `"completed"`
- [ ] Should NOT update if request is pending or rejected
- [ ] Check in `rentals/frontend/admin.html` or backend logic:
  - When approving a request, update `customers.current_vehicle = <vehicle_rego>`
  - When rejecting, do NOT update
- [ ] Verify in Supabase:
  - Pending request → `customers.current_vehicle` is NULL or old vehicle
  - After approval → `customers.current_vehicle` = new vehicle rego
- **Test:**
  - Submit request → `current_vehicle` should NOT change
  - Admin approves request → `current_vehicle` should update
  - Admin rejects request → `current_vehicle` should NOT change

### 3.6 Last Request Type Updates Correctly After Each Workflow Step
- [ ] Customer profile field `last_request_type` should update when:
  - [ ] New pickup is completed → `last_request_type = "pickup"`
  - [ ] Drop-off is completed → `last_request_type = "drop-off"`
  - [ ] Swap is completed → `last_request_type = "swap"`
- [ ] Should NOT update if request is rejected or pending
- [ ] Check in backend/admin logic:
  - When `rental_status` transitions to `"completed"`, update `customers.last_request_type`
- [ ] Verify in Supabase:
  - `booking_requests` status = "completed", request_type = "pickup" → `customers.last_request_type = "pickup"`
- **Test:**
  - Complete a pickup request → `last_request_type` should be `"pickup"`
  - Complete a swap request next → `last_request_type` should change to `"swap"`

---

## SECTION 4: FLEET LOGIC — STATE CONSISTENCY

**Status:** ⚠️ NOT STARTED  
**Risk:** Vehicle double-assignment, swap state corruption, availability miscounts

### 4.1 Vehicle Never Appears Available If Already Assigned
- [ ] If vehicle has active `current_assignment` (not NULL), it must NOT appear in "available vehicles" list
- [ ] Check in `rentals/frontend/admin.html` fleet tab or vehicle listing:
  - Filter logic should exclude vehicles where `status = "assigned"`
- [ ] In Supabase `vehicles` table:
  - `status` field should be `"available"` only if `current_assignment IS NULL`
- **Test:**
  - Create vehicle, assign it to active booking
  - Refresh admin fleet view
  - Vehicle should NOT appear in available list

### 4.2 Vehicle Never Assigned to Two Active Requests
- [ ] Database constraint MUST prevent this
- [ ] Check `supabase-security-hardening.sql`:
  - Should have constraint: `UNIQUE(vehicle_id) WHERE status = "active"` or similar
  - Or RLS policy that prevents duplicate assignments
- [ ] Before assigning a vehicle:
  - Check if it already has an active `current_assignment`
  - Block assignment with error message
- **Test:**
  - Assign vehicle to request 1 (status = "approved")
  - Try to assign same vehicle to request 2
  - Should fail with error: "Vehicle already assigned"

### 4.3 Drop-off Releases Vehicle Only When Return Completed
- [ ] When drop-off request is submitted (return started):
  - [ ] Vehicle should still be assigned (not released yet)
  - [ ] Status should be `"in-transit-return"` or similar (not `"available"`)
- [ ] When drop-off confirmed (return completed):
  - [ ] Vehicle should release: `current_assignment = NULL`, `status = "available"`
- [ ] Check in `rentals/frontend/service.html` drop-off handler:
  - First submission sets up return (vehicle still assigned)
  - Final confirmation releases vehicle
- **Test:**
  - Request drop-off
  - Check vehicle status → should still be assigned
  - Confirm drop-off
  - Check vehicle status → should be available

### 4.4 Swap Frees Old Vehicle and Assigns New One Correctly
- [ ] Single swap action MUST update both vehicles in same transaction:
  - [ ] Old vehicle: `current_assignment = NULL`, `status = "available"`
  - [ ] New vehicle: `current_assignment = <new_request_id>`, `status = "assigned"`
- [ ] Check in `rentals/frontend/service.html` or backend swap logic:
  - Should be one atomic transaction (not separate updates that could fail halfway)
- [ ] Verify in Supabase:
  - Old vehicle row: `current_assignment = NULL`
  - New vehicle row: `current_assignment = <new_booking_id>`
  - Both updated in same seconds (check `updated_at` timestamps)
- **Test:**
  - Submit swap request (old vehicle = ABC123, new vehicle = XYZ789)
  - Check vehicles table:
    - ABC123: `current_assignment = NULL`
    - XYZ789: `current_assignment = <request_id>`

### 4.5 Fleet Tab Counts Always Match Real State
- [ ] Count of "available vehicles" in admin dashboard should match:
  - `SELECT COUNT(*) FROM vehicles WHERE status = "available"`
- [ ] Count of "active rentals" should match:
  - `SELECT COUNT(*) FROM booking_requests WHERE rental_status IN ("approved", "in-transit")`
- [ ] Check in `rentals/frontend/admin.html` → fleet stats section
- **Test:**
  - Look at fleet counts in admin dashboard
  - Run counts in Supabase SQL editor
  - Counts should match exactly
  - After creating/completing requests, refresh and verify counts update

### 4.6 Admin Manual Edits Do Not Create Impossible Vehicle States
- [ ] If admin manually edits vehicle or request:
  - [ ] Cannot set vehicle to `status = "available"` if still has `current_assignment`
  - [ ] Cannot set `current_assignment` without also setting `status = "assigned"`
  - [ ] Cannot assign same vehicle to two different requests
- [ ] Check in `rentals/frontend/admin-enhanced.js` or admin edit form:
  - Add validation before save:
    ```javascript
    if (vehicleStatus === "available" && currentAssignment !== null) {
      alert("Error: Cannot mark vehicle available while it has an active assignment");
      return;
    }
    ```
- **Test:**
  - Admin tries to set vehicle to `available` while it has assignment → should be blocked

---

## SECTION 5: ADMIN AUTHORIZATION — RLS AND ROLE ENFORCEMENT

**Status:** ⚠️ PARTIALLY COMPLETE  
**Risk:** Frontend-only auth can be bypassed; RLS not tested against all role combinations

### 5.1 Do Not Trust admin.html Access by Itself
- [ ] Simply loading `admin.html` should NOT grant access
- [ ] Must check:
  1. User is logged in (Supabase Auth session exists)
  2. User has admin role (JWT claims or user metadata)
  3. Every database query should verify role server-side (RLS policy)
- [ ] Check `rentals/frontend/admin.html`:
  - On page load, should run:
    ```javascript
    const { data: { session } } = await client.auth.getSession();
    if (!session || !hasAdminRole(session.user)) {
      window.location.href = 'login.html';
      return;
    }
    ```
- **Test:** Open admin.html without logging in → should redirect to login.html

### 5.2 All Admin Reads/Writes Blocked Unless Role Checks Pass
- [ ] Every data fetch from `admin.html` must be behind RLS policy check
- [ ] Check `supabase-security-hardening.sql` for admin-level policies:
  - Read policy: `role = 'admin'` must pass before query
  - Write policy: `role = 'admin'` must pass before insert/update
- [ ] Verify in Supabase RLS editor:
  - `booking_requests` table → select, insert, update, delete all have admin check
  - `vehicles` table → same checks
  - `customers` table → same checks
- **Test:** 
  - Log in as regular customer user (not admin)
  - Try to access admin features (change request status, edit vehicle)
  - Should be blocked with error

### 5.3 Enable RLS on Every Exposed Table
- [ ] Check Supabase project:
  - Go to SQL Editor → run:
    ```sql
    SELECT * FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name IN 
    ('booking_requests', 'vehicles', 'customers', 'invoices', 'offers', 'offer_messages', 'payment_intents');
    ```
  - Then check RLS status for each table
- [ ] Tables that should have RLS enabled:
  - [ ] `booking_requests` — enable
  - [ ] `vehicles` — enable
  - [ ] `customers` — enable
  - [ ] `invoices` — enable
  - [ ] `offers` — enable
  - [ ] `offer_messages` — enable
  - [ ] `payment_intents` — enable
- [ ] Run in Supabase SQL Editor for each table:
  ```sql
  ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
  ```
- **Verify:** Supabase UI should show "RLS enabled" (green) for each table

### 5.4 Test Select/Insert/Update/Delete Rules Separately
- [ ] For each table, test each RLS policy type:
  - [ ] **Select rule:** Admin can read, customer cannot read other customers' records
  - [ ] **Insert rule:** Customer can create own requests, cannot create as other customer
  - [ ] **Update rule:** Admin can update any record, customer can only update own
  - [ ] **Delete rule:** Only admin can delete (if allowed), customer cannot
- [ ] Create test cases:
  ```javascript
  // Test as customer user:
  const { data, error } = await client
    .from('booking_requests')
    .select()
    .eq('customer_id', OTHER_CUSTOMER_ID); // Should fail/return empty
  // Error should indicate permission denied
  
  // Test as admin:
  const { data, error } = await client
    .from('booking_requests')
    .select()
    .eq('customer_id', ANYONE_CUSTOMER_ID); // Should succeed
  ```
- **File:** `supabase-security-hardening.sql` — review each RLS policy

### 5.5 Test Separate User Roles: Anonymous, Customer, Admin
- [ ] Create 3 test accounts:
  - [ ] **Anonymous** (no login)
  - [ ] **Customer** (regular user, not admin)
  - [ ] **Admin** (has `role = 'admin'`)
- [ ] For each user type, test:
  - Can they load service.html? → Anon/Customer yes, but limited functionality
  - Can they load admin.html? → Only Admin yes
  - Can they read other customers' records? → No (should be blocked)
  - Can they create requests? → Customer yes, Anon no, Admin yes
  - Can they modify request status? → Only Admin yes
- **Test File:** Create manual test script or use Supabase test client library
- **Example test:**
  ```javascript
  // As anon:
  const { data, error } = await anonClient.from('customers').select();
  // Should be blocked or empty
  
  // As admin:
  const { data, error } = await adminClient.from('customers').select();
  // Should return all customers
  ```

### 5.6 Users Cannot Change IDs in Requests and Read Other Records
- [ ] URL parameter or form field injection test:
  - [ ] Edit service.html URL to change customer ID in request body
  - [ ] Customer can NOT create request with `customer_id = SOMEONE_ELSE_ID`
  - [ ] Should either: ignore injected ID and use logged-in user ID, or fail with error
- [ ] RLS policy should enforce:
  - [ ] INSERT into `booking_requests` only if `customer_id = current_user_id`
  - [ ] UPDATE `booking_requests` only if `customer_id = current_user_id` (customer) or role = 'admin'
- [ ] Check `supabase-security-hardening.sql` for this policy:
  ```sql
  CREATE POLICY "Customers can create own requests" ON booking_requests
  FOR INSERT
  WITH CHECK (customer_id = auth.uid());
  ```
- **Test:**
  - Log in as customer 1
  - Try to create request with `customer_id = customer_2_id` in form data
  - Should fail or be replaced with customer 1's ID

### 5.7 Storage Rules Protect License Photos
- [ ] License photos should be stored in Supabase Storage in private bucket
- [ ] Check Supabase Storage policies:
  - [ ] Anon user cannot read/write
  - [ ] Customer can read/write own photos only
  - [ ] Admin can read any photos
- [ ] Verify in Supabase UI → Storage → `license-photos` bucket → Policies
- [ ] Test:
  - Customer uploads license photo → stored with path including customer_id
  - Other customer cannot access via URL guessing
  - Direct URL to photo should fail without auth token
- **File:** Check storage policies in Supabase console

### 5.8 No Service Role Key Exposed in Frontend Code
- [ ] Search all `.js` and `.html` files for `SUPABASE_SERVICE_KEY` or `service_role`
- [ ] Check `rentals/frontend/supabase-config.js`:
  - [ ] Should only contain `SUPABASE_URL` and `SUPABASE_ANON_KEY` (not service role key)
  - [ ] Service role key should ONLY be in backend/server, never in browser
- **Search:**
  ```bash
  grep -r "service_role\|SERVICE_ROLE\|service_key" rentals/frontend/
  grep -r "eyJ.*\." rentals/frontend/ # Look for JWT-like secrets
  ```
- **Test:**
  - Open browser DevTools → Network tab
  - Look at requests to Supabase
  - Should NOT see service role key in Authorization headers or request bodies

---

## SECTION 6: ERROR HANDLING — FAILURE CASES

**Status:** ⚠️ NOT STARTED  
**Risk:** Silent failures, incorrect success messages, confusing error display

### 6.1 Show Proper Message When Database Insert Fails
- [ ] When `saveCustomerToSupabase()` or similar fails:
  - [ ] Do NOT show generic "Error" or no message
  - [ ] Show specific error: `"Failed to save customer: Phone already exists"` or `"Database connection failed"`
- [ ] Check `rentals/frontend/service.html` and `rentals/frontend/app.js`:
  - Wrap DB calls in try/catch:
    ```javascript
    try {
      const { data, error } = await client.from('customers').insert([...]);
      if (error) {
        alert(`Error saving customer: ${error.message}`);
        return;
      }
    } catch (e) {
      alert(`Network error: ${e.message}`);
    }
    ```
- **Test:** 
  - Simulate DB failure (e.g., disconnect internet)
  - Try to submit form
  - Should show clear error message, not blank/stale UI

### 6.2 Show Proper Message When Auth/Session Expires
- [ ] When user's session expires while they're using app:
  - [ ] Not a silent fail or redirect loop
  - [ ] Show message: `"Your session has expired. Please log in again."` with login link
- [ ] Check `rentals/frontend/app.js` and `rentals/frontend/admin.html`:
  - Add session refresh check:
    ```javascript
    const { data: { session } } = await client.auth.getSession();
    if (!session) {
      alert('Your session expired. Redirecting to login...');
      window.location.href = 'login.html';
      return;
    }
    ```
- **Test:**
  - Log in, wait for session to expire (15-30 min, or manually invalidate)
  - Try to perform action (click submit, refresh page)
  - Should see error message and be offered login link

### 6.3 Show Proper Message When Photo Upload Fails
- [ ] When file upload to Storage fails (size limit, network, permission):
  - [ ] Not a silent skip or "success" false positive
  - [ ] Show message: `"Photo upload failed: File too large (max 5MB)"` or similar
- [ ] Check `rentals/frontend/service.html`:
  - Wrap Storage.upload() in try/catch:
    ```javascript
    try {
      const { error } = await client.storage
        .from('license-photos')
        .upload(path, file);
      if (error) {
        alert(`Photo upload failed: ${error.message}`);
        return;
      }
    } catch (e) {
      alert(`Upload error: ${e.message}`);
    }
    ```
- **Test:**
  - Try uploading 20MB file → should show "too large" error
  - Try uploading while disconnected → should show network error
  - Try uploading unsupported file type → should show format error

### 6.4 Show Proper Message When Rego/Customer Not Found
- [ ] When rego lookup returns no vehicle:
  - [ ] Not "undefined" or blank
  - [ ] Show message: `"Vehicle with rego ABC123 not found in fleet"`
- [ ] When customer lookup returns no match:
  - [ ] Show message: `"No customer record found for phone 0412345678"`
- [ ] Check `rentals/frontend/app.js`:
  - Lookup functions should explicitly check for empty results:
    ```javascript
    const { data, error } = await client
      .from('vehicles')
      .select()
      .eq('rego', normalizedRego);
    if (!data || data.length === 0) {
      alert(`Vehicle with rego ${rego} not found`);
      return null;
    }
    ```
- **Test:**
  - Enter invalid rego in service.html
  - Try to submit
  - Should see: "Vehicle not found"

### 6.5 Show Proper Message When Admin Has No Data to View
- [ ] If admin opens a tab with no data (e.g., no active rentals):
  - [ ] Not blank page or "undefined" error
  - [ ] Show message: `"No active rentals at this time"` or placeholder UI
- [ ] Check `rentals/frontend/admin.html`:
  - After fetching data:
    ```javascript
    if (!data || data.length === 0) {
      document.getElementById('rentals-list').innerHTML = 
        '<p>No active rentals at this time</p>';
      return;
    }
    ```
- **Test:**
  - Create fresh database (no requests yet)
  - Open admin.html
  - Should see "No data" message, not blank/broken UI

### 6.6 Prevent "Success" UI If Database Action Actually Failed
- [ ] Critical: Do NOT show "Request submitted successfully" if DB insert actually failed
- [ ] Check all DB operations in `rentals/frontend/service.html` and `rentals/frontend/admin.html`:
  - [ ] Before showing success message, check response:
    ```javascript
    if (error) {
      alert(`Error: ${error.message}`);
      return; // Don't show success
    }
    // Only here: show success
    alert('Request submitted successfully!');
    ```
  - [ ] Not just checking `if (data)` (could be empty array = falsy but no error)
- **Test:**
  - Manually break Supabase connection or permission
  - Submit form
  - Should show error message, NOT "success"

### 6.7 Handle Network Disconnects Gracefully
- [ ] When user loses internet while submitting:
  - [ ] Not a crash or undefined state
  - [ ] Show message: `"Network error. Please check your connection and try again."`
  - [ ] Allow user to retry (button should be re-enabled)
- [ ] Check `rentals/frontend/service.html` form submission:
  - [ ] Catch network errors:
    ```javascript
    try {
      const { error } = await client.from(...).insert(...);
      if (error) throw error;
    } catch (e) {
      if (e.message.includes('fetch') || e.message.includes('network')) {
        alert('Network error. Please try again.');
      } else {
        alert(`Error: ${e.message}`);
      }
      submitBtn.disabled = false; // Re-enable retry
    }
    ```
- **Test:**
  - Disable internet while submitting form
  - Should show error and allow retry after reconnecting

### 6.8 Handle Partial Submit Failures (Upload Succeeds, DB Fails)
- [ ] Edge case: Photo upload succeeds, but customer insert fails
  - [ ] Should NOT leave orphaned photo in Storage
  - [ ] Either: rollback upload, or link it to customer on retry
- [ ] Check `rentals/frontend/service.html`:
  - Option 1 (safer): Save customer first, then upload photos
    ```javascript
    // 1. Save customer
    const { data: customer, error: custError } = await client
      .from('customers').insert([...]);
    if (custError) {
      alert('Failed to save customer');
      return; // Don't upload photo yet
    }
    // 2. Upload photo
    const { error: uploadError } = await client.storage
      .from('license-photos')
      .upload(`${customer.id}/${file.name}`, file);
    if (uploadError) {
      alert('Photo upload failed, but customer was saved.');
      return;
    }
    ```
  - Option 2: Wrap in transaction (if backend supports)
- **Test:**
  - Simulate upload success + DB failure
  - Should not create orphaned storage files or inconsistent data

---

## SECTION 7: DATA INTEGRITY — DATABASE CONSTRAINTS & STRUCTURE

**Status:** ⚠️ PARTIALLY COMPLETE (SQL created, not applied)  
**Reference:** `supabase-security-hardening.sql`

### 7.1 Required Constraints in Database, Not Just UI
- [ ] Apply `supabase-security-hardening.sql` to your Supabase instance:
  - [ ] Open Supabase console → Project Settings → SQL Editor
  - [ ] Copy contents of `supabase-security-hardening.sql`
  - [ ] Paste and run
- [ ] Verify constraints exist for:
  - [ ] `name NOT NULL` and `name != ''` (not blank)
  - [ ] `phone NOT NULL` and matches format
  - [ ] `email NOT NULL` and has `@` and `.`
  - [ ] `rego NOT NULL` and `UNIQUE` (only one vehicle per rego)
  - [ ] `rental_status` in allowed set (`'pending'`, `'approved'`, `'completed'`, etc.)
  - [ ] `request_type` in set (`'pickup'`, `'drop-off'`, `'swap'`)
- **Run in Supabase SQL Editor:**
  ```sql
  SELECT * FROM information_schema.table_constraints 
  WHERE table_name IN ('customers', 'vehicles', 'booking_requests');
  ```
- **Verify:** Each constraint shows in the output

### 7.2 Foreign Key Constraints
- [ ] Check that tables reference each other correctly:
  - [ ] `booking_requests.customer_id` → `customers.id` (FK)
  - [ ] `booking_requests.vehicle_id` → `vehicles.id` (FK)
  - [ ] `invoices.booking_id` → `booking_requests.id` (FK)
- [ ] Verify in Supabase SQL Editor:
  ```sql
  SELECT * FROM information_schema.table_constraints 
  WHERE constraint_type = 'FOREIGN KEY';
  ```
- **Test:**
  - Try to delete a customer with active booking → should fail (FK constraint)
  - Try to delete a vehicle with active assignment → should fail

### 7.3 Audit Fields on All Tables
- [ ] Each table should have:
  - [ ] `created_at` (auto-set on insert, NOT NULL)
  - [ ] `updated_at` (auto-set on insert/update, NOT NULL)
  - [ ] `created_by` (user ID, auto-set, NOT NULL)
  - [ ] `last_modified_by` (user ID, auto-set on update)
- [ ] Check in `supabase-security-hardening.sql`:
  - [ ] Audit triggers defined for each table
  - [ ] Example:
    ```sql
    CREATE TRIGGER customers_audit_trigger
    BEFORE INSERT OR UPDATE ON customers
    FOR EACH ROW
    BEGIN
      SET NEW.updated_at = NOW();
      SET NEW.last_modified_by = auth.uid();
    END;
    ```
- **Verify in Supabase:**
  - Create a record
  - Check that `created_at`, `created_by` are filled
  - Update record
  - Check that `updated_at`, `last_modified_by` changed

### 7.4 Indexes on Phone, Email, Rego, Status
- [ ] These are frequently looked up, so should be indexed for performance:
  - [ ] `customers.phone` — indexed
  - [ ] `customers.email` — indexed
  - [ ] `vehicles.rego` — indexed
  - [ ] `booking_requests.rental_status` — indexed
- [ ] Check in `supabase-security-hardening.sql`:
  - [ ] Indexes created:
    ```sql
    CREATE INDEX idx_customers_phone ON customers(phone);
    CREATE INDEX idx_customers_email ON customers(email);
    CREATE INDEX idx_vehicles_rego ON vehicles(rego);
    CREATE INDEX idx_booking_requests_status ON booking_requests(rental_status);
    ```
- **Verify in Supabase:**
  - Go to Table Designer → select each table
  - Check "Indexes" section for above index names

### 7.5 Avoid Overwriting Historical Request Evidence
- [ ] When customer updates profile (e.g., phone number changes):
  - [ ] Should NOT overwrite linked request evidence photos
  - [ ] Requests should have immutable copies of customer info at time of request
- [ ] Database schema:
  - [ ] `booking_requests` should have own copies of `customer_name`, `customer_phone` (not just `customer_id`)
  - [ ] This prevents profile update from breaking request history
- [ ] Check table structure:
  - [ ] `booking_requests` should have columns:
    - `customer_id` (FK to customers)
    - `customer_name_snapshot` (immutable copy at time of request)
    - `customer_phone_snapshot` (immutable copy)
- **Test:**
  - Create request with customer name `"Ali Ahmed"`
  - Later, customer updates profile to `"Alice Ahmed"`
  - Request history should still show `"Ali Ahmed"` (snapshot), not updated name

### 7.6 Keep Request History Immutable Where Possible
- [ ] Once a request is completed, critical fields should not change:
  - [ ] Request type (pickup/drop-off/swap)
  - [ ] Vehicle assigned
  - [ ] Customer name/phone (snapshots)
  - [ ] Timestamps
- [ ] Allow updates ONLY for:
  - [ ] Status (pending → approved → completed)
  - [ ] Admin notes
  - [ ] Evidence photos (if not yet completed)
- [ ] Check RLS policies:
  - [ ] `UPDATE` policy should restrict which columns can be modified:
    ```sql
    CREATE POLICY "Can only update certain fields" ON booking_requests
    FOR UPDATE
    USING (role = 'admin')
    WITH CHECK (
      -- Only allow these to change:
      old.request_type = new.request_type AND
      old.vehicle_id = new.vehicle_id AND
      old.customer_id = new.customer_id
    );
    ```
- **Test:**
  - Complete a request
  - Try to edit completed request → should be blocked or limited

---

## SECTION 8: AUTOMATED TESTS — UNIT & INTEGRATION

**Status:** ❌ NOT STARTED  
**Framework:** Jest or similar Node test runner  
**Location:** Create `tests/` directory

### 8.1 Unit Tests for Validation Functions
- [ ] Create `tests/validation.test.js`:
  ```javascript
  const { VeeraValidation } = require('../rentals/frontend/validation/request-validation.js');
  
  describe('Validation', () => {
    test('isValidName rejects blank', () => {
      expect(VeeraValidation.isValidName("")).toBe(false);
      expect(VeeraValidation.isValidName("   ")).toBe(false);
    });
    test('isValidPhone normalizes and validates', () => {
      const result = VeeraValidation.isValidPhone("04 1234 5678");
      expect(result.normalized).toBe("0412345678");
      expect(result.valid).toBe(true);
    });
    test('isValidEmail normalizes to lowercase', () => {
      const result = VeeraValidation.isValidEmail("Ali@EXAMPLE.COM");
      expect(result.normalized).toBe("ali@example.com");
    });
    test('isValidRego normalizes to uppercase', () => {
      const result = VeeraValidation.isValidRego("abc 123");
      expect(result.normalized).toBe("ABC123");
    });
  });
  ```
- [ ] Run: `npm test tests/validation.test.js`
- [ ] Target: 100% pass rate

### 8.2 Unit Tests for Status Transition Rules
- [ ] Create `tests/status-transitions.test.js`:
  ```javascript
  describe('Status Transitions', () => {
    test('Pickup creates request_type = "pickup"', async () => {
      const result = await createPickupRequest({...});
      expect(result.request_type).toBe('pickup');
      expect(result.rental_status).toBe('pending');
    });
    test('Swap creates request_type = "swap"', async () => {
      const result = await createSwapRequest({...});
      expect(result.request_type).toBe('swap');
    });
    test('Completed request cannot remain active', async () => {
      const request = await createAndCompleteRequest({...});
      const inActive = await isRequestActive(request.id);
      expect(inActive).toBe(false);
    });
  });
  ```

### 8.3 Unit Tests for Customer Deduplication
- [ ] Create `tests/deduplication.test.js`:
  ```javascript
  describe('Deduplication', () => {
    test('Phone with different formats creates one customer', async () => {
      const cust1 = await findOrCreateCustomer({ phone: "0412345678" });
      const cust2 = await findOrCreateCustomer({ phone: "04 1234 5678" });
      expect(cust1.id).toBe(cust2.id); // Same record
    });
    test('Email case-insensitive lookup', async () => {
      const cust1 = await findOrCreateCustomer({ email: "Ali@Example.COM" });
      const cust2 = await findOrCreateCustomer({ email: "ali@example.com" });
      expect(cust1.id).toBe(cust2.id);
    });
    test('Rego case-insensitive lookup', async () => {
      const v1 = await findVehicleByRego("abc 123");
      const v2 = await findVehicleByRego("ABC123");
      expect(v1.id).toBe(v2.id);
    });
  });
  ```

### 8.4 Integration Test: Pickup Flow
- [ ] Create `tests/flows/pickup.integration.test.js`:
  ```javascript
  describe('Pickup Flow', () => {
    test('Complete pickup: form → validation → DB → rego assign', async () => {
      // 1. Submit form with valid data
      const payload = { name: "Ali", phone: "0412345678", rego: "ABC123" };
      const validation = validateServicePayload(payload);
      expect(validation.valid).toBe(true);
      
      // 2. Save to DB
      const customer = await saveCustomerToSupabase(payload);
      expect(customer.id).toBeDefined();
      
      // 3. Assign vehicle
      const vehicle = await assignVehicleToCustomer(customer.id, "ABC123");
      expect(vehicle.current_assignment).toBe(customer.id);
      
      // 4. Verify state
      const freshCustomer = await getCustomer(customer.id);
      expect(freshCustomer.current_vehicle).toBe("ABC123");
    });
    test('Pickup creates request_type = "pickup", status = "pending"', async () => {
      // ... similar flow
      expect(booking.request_type).toBe("pickup");
      expect(booking.rental_status).toBe("pending");
    });
    test('Double-click submit creates only 1 record', async () => {
      // Simulate rapid submissions
      const p1 = submitPickupForm(payload);
      const p2 = submitPickupForm(payload);
      const [r1, r2] = await Promise.all([p1, p2]);
      
      // Should have created only 1 record or linked to same one
      const records = await getCustomerRecords("0412345678");
      expect(records.length).toBe(1);
    });
  });
  ```

### 8.5 Integration Test: Drop-off Flow
- [ ] Create `tests/flows/dropoff.integration.test.js`:
  ```javascript
  describe('Drop-off Flow', () => {
    test('Drop-off request does not release vehicle immediately', async () => {
      const request = await createDropoffRequest({...});
      const vehicle = await getVehicle(request.vehicle_id);
      expect(vehicle.status).toBe('in-transit-return'); // Not 'available' yet
    });
    test('Completing drop-off releases vehicle', async () => {
      const request = await createDropoffRequest({...});
      await completeDropoff(request.id);
      const vehicle = await getVehicle(request.vehicle_id);
      expect(vehicle.status).toBe('available');
      expect(vehicle.current_assignment).toBeNull();
    });
  });
  ```

### 8.6 Integration Test: Swap Flow
- [ ] Create `tests/flows/swap.integration.test.js`:
  ```javascript
  describe('Swap Flow', () => {
    test('Swap updates both vehicles in one transaction', async () => {
      const oldVehicle = await getVehicle("ABC123");
      const newVehicle = await getVehicle("XYZ789");
      
      const swap = await createSwapRequest({
        old_rego: "ABC123",
        new_rego: "XYZ789"
      });
      
      const updatedOld = await getVehicle("ABC123");
      const updatedNew = await getVehicle("XYZ789");
      
      expect(updatedOld.current_assignment).toBeNull();
      expect(updatedNew.current_assignment).toBe(swap.id);
      // Timestamps should be within 1 second of each other
      const timeDiff = Math.abs(
        updatedOld.updated_at - updatedNew.updated_at
      );
      expect(timeDiff).toBeLessThan(1000);
    });
  });
  ```

### 8.7 RLS Policy Test Cases
- [ ] Create `tests/rls.test.js`:
  ```javascript
  describe('RLS Policies', () => {
    test('Customer cannot read other customer records', async () => {
      const cust1Client = createSupabaseClient(CUSTOMER_1_TOKEN);
      const cust2Client = createSupabaseClient(CUSTOMER_2_TOKEN);
      
      const { data, error } = await cust1Client
        .from('booking_requests')
        .select()
        .eq('customer_id', CUSTOMER_2_ID);
      
      expect(error).toBeDefined(); // Permission denied
    });
    test('Admin can read any records', async () => {
      const adminClient = createSupabaseClient(ADMIN_TOKEN);
      const { data, error } = await adminClient
        .from('booking_requests')
        .select();
      expect(error).toBeNull();
      expect(data.length).toBeGreaterThan(0);
    });
    test('Anonymous user cannot modify data', async () => {
      const anonClient = createSupabaseClient(ANON_TOKEN);
      const { error } = await anonClient
        .from('booking_requests')
        .insert([{ customer_name: "Hacker" }]);
      expect(error).toBeDefined(); // Permission denied
    });
  });
  ```

### 8.8 Admin Review Test
- [ ] Create `tests/admin.test.js`:
  ```javascript
  describe('Admin Features', () => {
    test('Admin cannot access without role', async () => {
      const userWithoutRole = createSupabaseClient(CUSTOMER_TOKEN);
      const { error } = await userWithoutRole
        .from('booking_requests')
        .update({ rental_status: "approved" })
        .eq('id', REQUEST_ID);
      expect(error).toBeDefined();
    });
    test('Admin can view all requests', async () => {
      const admin = createSupabaseClient(ADMIN_TOKEN);
      const { data } = await admin.from('booking_requests').select();
      expect(data.length).toBeGreaterThan(0);
    });
  });
  ```

### 8.9 Regression Test: Fleet Assignment Logic
- [ ] Create `tests/fleet.test.js`:
  ```javascript
  describe('Fleet Assignment', () => {
    test('Vehicle assigned to request is not available', async () => {
      const available = await listAvailableVehicles();
      const countBefore = available.length;
      
      await assignVehicleToCustomer(CUSTOMER_ID, "ABC123");
      
      const availableAfter = await listAvailableVehicles();
      expect(availableAfter.length).toBe(countBefore - 1);
      expect(availableAfter.map(v => v.rego)).not.toContain("ABC123");
    });
    test('Vehicle cannot be assigned to two requests', async () => {
      await assignVehicleToCustomer(CUSTOMER_1, "ABC123");
      
      const { error } = await assignVehicleToCustomer(CUSTOMER_2, "ABC123");
      expect(error).toBeDefined(); // Constraint violation
    });
  });
  ```

### 8.10 Setup Test Runner
- [ ] In project root, create `jest.config.js`:
  ```javascript
  module.exports = {
    testEnvironment: 'node',
    testMatch: ['**/tests/**/*.test.js'],
    collectCoverage: true,
    coverageDirectory: 'coverage',
  };
  ```
- [ ] Add to `package.json`:
  ```json
  {
    "scripts": {
      "test": "jest",
      "test:coverage": "jest --coverage"
    },
    "devDependencies": {
      "jest": "^29.0.0",
      "@supabase/supabase-js": "^2.0.0"
    }
  }
  ```
- [ ] Run tests:
  ```bash
  npm install
  npm test
  ```
- [ ] Target: ≥80% code coverage

---

## SECTION 9: MANUAL REVIEW SCRIPT — REAL-WORLD TESTING

**Status:** ❌ NOT STARTED  
**Purpose:** Step-by-step manual testing checklist to verify all workflows work end-to-end

### 9.1 Setup Test Environment
- [ ] Create test Supabase project (separate from production)
- [ ] Create 3 test users:
  - [ ] **Customer 1:** email `test-customer-1@example.com`, password `Test123!`
  - [ ] **Customer 2:** email `test-customer-2@example.com`, password `Test123!`
  - [ ] **Admin:** email `admin@example.com`, password `Test123!`, set role = 'admin' in user metadata
- [ ] Create test vehicles:
  - [ ] Vehicle 1: rego `ABC123`, status `available`
  - [ ] Vehicle 2: rego `XYZ789`, status `available`
- [ ] Clear any existing booking_requests (start fresh)

### 9.2 Test Pickup Workflow
- [ ] **Step 1:** Log in as Customer 1
- [ ] **Step 2:** Open service.html, select "Pickup"
- [ ] **Step 3:** Fill form:
  - Name: `Test Customer One`
  - Phone: `0412 345 678` (with space, should normalize)
  - Email: `Ali@EXAMPLE.COM` (mixed case, should normalize)
  - Rego: `abc 123` (lowercase with space, should normalize)
  - Mileage: `50000`
  - License Photo: upload valid JPEG < 5MB
- [ ] **Step 4:** Click Submit
- [ ] **Verify:**
  - [ ] Form validation passes (no errors)
  - [ ] Success message shown
  - [ ] Customer record created in Supabase:
    - [ ] `name = "Test Customer One"`
    - [ ] `phone = "0412345678"` (normalized)
    - [ ] `email = "ali@example.com"` (lowercase)
  - [ ] Booking request created:
    - [ ] `request_type = "pickup"`
    - [ ] `rental_status = "pending"`
    - [ ] `vehicle_id` linked to ABC123
  - [ ] Vehicle updated:
    - [ ] `rego = "ABC123"` (normalized)
    - [ ] `current_assignment = <request_id>`
    - [ ] `status = "assigned"`
  - [ ] Photo uploaded to Storage: `license-photos/<customer_id>/`

### 9.3 Test Drop-off Workflow
- [ ] **Step 1:** Admin approves Customer 1's pickup request
- [ ] **Step 2:** Log in as Customer 1
- [ ] **Step 3:** Open service.html, select "Drop-off"
- [ ] **Step 4:** Fill form:
  - Rego: `ABC123`
  - Mileage: `50100` (increased by 100 km)
  - Return Photo: upload valid evidence photo
- [ ] **Step 5:** Click Submit
- [ ] **Verify:**
  - [ ] New booking_request created with `request_type = "drop-off"`
  - [ ] Vehicle status changed to `"in-transit-return"` (not yet `"available"`)
  - [ ] Previous pickup request status = `"return_pending"`
- [ ] **Step 6:** Admin confirms drop-off
- [ ] **Verify:**
  - [ ] Booking request `rental_status = "completed"`
  - [ ] Vehicle status = `"available"` (released)
  - [ ] Vehicle `current_assignment = NULL`

### 9.4 Test Swap Workflow
- [ ] **Step 1:** Admin approves Customer 1's pickup on ABC123
- [ ] **Step 2:** Customer 1 requests swap (ABC123 → XYZ789)
- [ ] **Step 3:** Verify:
  - [ ] Old vehicle ABC123: `status = "available"`, `current_assignment = NULL`
  - [ ] New vehicle XYZ789: `status = "assigned"`, `current_assignment = <swap_request_id>`
  - [ ] Both timestamps within 1 second of each other
- [ ] **Step 4:** Admin confirms swap completed
- [ ] **Verify:**
  - [ ] Swap request `rental_status = "completed"`

### 9.5 Test Deduplication
- [ ] **Step 1:** Customer 1 makes pickup with:
  - Phone: `0412 345 678`
  - Email: `Ali@EXAMPLE.COM`
  - Rego: `abc 123`
- [ ] **Step 2:** Customer 1 makes another pickup with:
  - Phone: `0412345678` (no space)
  - Email: `ali@example.com` (lowercase)
  - Rego: `ABC123` (uppercase)
- [ ] **Verify:**
  - [ ] Only 1 customer record in DB (not duplicated)
  - [ ] Both requests linked to same `customer_id`

### 9.6 Test Admin Permissions
- [ ] **Step 1:** Log in as Customer 1 (not admin)
- [ ] **Step 2:** Try to access admin.html
- [ ] **Verify:** Redirected to login.html (access denied)
- [ ] **Step 3:** Log in as Admin
- [ ] **Step 4:** Open admin.html
- [ ] **Verify:** Admin dashboard loads, can see all requests, can change status
- [ ] **Step 5:** Try to change request status to invalid value (e.g., "HACKED")
- [ ] **Verify:** RLS blocks update, shows error

### 9.7 Test RLS Policies
- [ ] **Step 1:** Open browser DevTools → Network tab
- [ ] **Step 2:** Log in as Customer 1
- [ ] **Step 3:** Try to fetch Customer 2's records (via console):
  ```javascript
  const { data, error } = await client.from('customers')
    .select()
    .eq('id', CUSTOMER_2_ID);
  console.log(error); // Should show permission denied
  ```
- [ ] **Verify:** Error is returned (not empty, not all records)

### 9.8 Test Error Handling
- [ ] **Test Case 1: Invalid name**
  - [ ] Submit with name = `"   "` (whitespace only)
  - [ ] Verify: Error message shown, form not submitted
- [ ] **Test Case 2: Network disconnect**
  - [ ] Disable internet
  - [ ] Try to submit form
  - [ ] Verify: "Network error" message shown
  - [ ] Re-enable internet, retry
  - [ ] Verify: Form submits successfully
- [ ] **Test Case 3: Invalid file upload**
  - [ ] Try to upload 20MB file as license photo
  - [ ] Verify: "File too large" error shown
  - [ ] Try to upload `.pdf` file
  - [ ] Verify: "File type not supported" error shown

### 9.9 Test Refresh Consistency
- [ ] **Step 1:** Customer 1 makes pickup request
- [ ] **Step 2:** Without refreshing, admin approves it (in admin.html)
- [ ] **Step 3:** Refresh Customer 1's service.html page
- [ ] **Verify:**
  - [ ] Customer data reloads from DB (latest values)
  - [ ] Request status shows "approved" (not stale "pending")
  - [ ] Vehicle assignment shows updated state

### 9.10 Test Data Integrity
- [ ] **Step 1:** Complete a pickup + drop-off flow
- [ ] **Step 2:** Try to delete the customer record
- [ ] **Verify:** Deletion blocked by foreign key constraint
- [ ] **Step 3:** Check `booking_requests` audit fields:
  ```sql
  SELECT id, request_type, created_by, created_at, 
         last_modified_by, updated_at 
  FROM booking_requests 
  WHERE customer_id = '<test-customer-1>';
  ```
- [ ] **Verify:**
  - [ ] `created_by` = customer 1's user ID
  - [ ] `created_at` = when request was made
  - [ ] `updated_at` = when last modified
  - [ ] `last_modified_by` = admin or customer ID who made change

---

## SECTION 10: HIDDEN BUGS PROBE LIST — EDGE CASES & ABUSE

**Status:** ❌ NOT STARTED  
**Purpose:** Probe for common business logic and authorization bugs that survive basic testing

### 10.1 Request Logic Edge Cases
- [ ] **Bug Probe 1:** Change request type in URL/form after submission
  - Submit pickup, immediately change form `request_type` to "swap", submit again
  - Verify: Only 1 request created, second is ignored or fails
- [ ] **Bug Probe 2:** Change vehicle rego after approval
  - Approve pickup with rego ABC123, then change rego to XYZ789
  - Verify: Request stays linked to ABC123, not updated
- [ ] **Bug Probe 3:** Submit with blank mileage
  - Try to submit without mileage field
  - Verify: Validation fails with message
- [ ] **Bug Probe 4:** Submit negative mileage
  - Enter mileage = `-100`
  - Verify: Validation fails

### 10.2 Customer Linking Edge Cases
- [ ] **Bug Probe 1:** Same person, different phone format + different email
  - Create customer with phone `0412345678`, email `ali@example.com`
  - Create request with phone `04 1234 5678`, email `Ali@EXAMPLE.COM`
  - Verify: Linked to same customer (not duplicated)
- [ ] **Bug Probe 2:** Update customer profile, old request unaffected
  - Create request with customer name "Ali Ahmed"
  - Update customer profile to "Alice Ahmed"
  - View old request history
  - Verify: Old request still shows "Ali Ahmed" (snapshot, not updated)

### 10.3 Fleet State Edge Cases
- [ ] **Bug Probe 1:** Manually set vehicle to available while it has assignment
  - In Supabase, update vehicle to `status = "available"` while `current_assignment IS NOT NULL`
  - Try to use app: assign same vehicle to new customer
  - Verify: Either blocked by constraint, or caught by app logic
- [ ] **Bug Probe 2:** Swap where old and new vehicle are the same
  - Try to create swap with same rego for both
  - Verify: Rejected with error or no state change

### 10.4 Admin Permission Abuse
- [ ] **Bug Probe 1:** Customer tries to change request status
  - Log in as customer, open DevTools
  - Try to directly call backend update:
    ```javascript
    await client.from('booking_requests')
      .update({ rental_status: 'completed' })
      .eq('id', THEIR_REQUEST_ID);
    ```
  - Verify: Blocked by RLS policy (permission denied error)
- [ ] **Bug Probe 2:** Customer tries to view other customer data
  - Try:
    ```javascript
    await client.from('booking_requests')
      .select()
      .eq('customer_id', OTHER_CUSTOMER_ID);
    ```
  - Verify: Blocked or returns empty (permission denied)
- [ ] **Bug Probe 3:** Customer tries to modify admin-only field
  - Try to update `rental_status` on own request
  - Verify: Blocked by RLS or UI prevents it

### 10.5 Data Consistency Abuse
- [ ] **Bug Probe 1:** Create booking, delete vehicle mid-workflow
  - Create request with vehicle ABC123
  - Delete vehicle from fleet
  - Check if request is orphaned or handled gracefully
  - Verify: Either request auto-cancelled, or FK constraint prevents deletion
- [ ] **Bug Probe 2:** Change request ID in request body
  - Make API call to update request, change request ID in body
  - Verify: Either ignored, or only affects intended request
- [ ] **Bug Probe 3:** Insert record with future date
  - Try to create booking with `created_at = future date`
  - Verify: Overridden by server timestamp, not client value

### 10.6 Photo Upload Abuse
- [ ] **Bug Probe 1:** Upload zero-byte file
  - Try to submit with empty file
  - Verify: Rejected with error or handled gracefully
- [ ] **Bug Probe 2:** Upload huge file
  - Try to upload 100MB file
  - Verify: Rejected with "file too large" error before upload starts
- [ ] **Bug Probe 3:** Upload file with fake extension
  - Rename `.pdf` to `.jpg` and upload
  - Verify: Rejected by MIME type check, not just extension check
- [ ] **Bug Probe 4:** Guess storage URL for other customer's photo
  - Upload photo as Customer 1, note storage path
  - Try to access same path as Customer 2 (different user)
  - Verify: Access denied by Storage RLS policy

### 10.7 Status Transition Abuse
- [ ] **Bug Probe 1:** Approve a request twice
  - Admin approves request, then approves again
  - Verify: Second approval is idempotent (no state corruption)
- [ ] **Bug Probe 2:** Complete a request, then try to reject it
  - Request is completed, try to change status to "rejected"
  - Verify: Blocked by constraint or logic (immutable state)
- [ ] **Bug Probe 3:** Reject then re-approve
  - Reject request, then try to approve it
  - Verify: Either blocked, or handled correctly (vehicle re-assigned only if available)

### 10.8 Race Condition Probes
- [ ] **Bug Probe 1:** Two users submit same vehicle simultaneously
  - Simulate: Customer 1 and Customer 2 both try to request rego ABC123 at same time
  - Verify: Only 1 succeeds, other fails with "vehicle already assigned"
- [ ] **Bug Probe 2:** Two admins approve same request
  - Simulate: Two admin users both click "approve" on same request within 1 second
  - Verify: Only 1 succeeds, second sees already-approved status
- [ ] **Bug Probe 3:** Submit + refresh simultaneously
  - Click submit, immediately refresh page (Ctrl+R)
  - Verify: Either 1 record created, or handled gracefully

### 10.9 Authorization Boundary Tests
- [ ] **Bug Probe 1:** Copy admin auth token, use as customer
  - Impossible in practice, but if it were somehow possible:
  - Verify: Token should have role claim that RLS checks
- [ ] **Bug Probe 2:** Create request as customer, change customer_id in request
  - Make API call with body `{ customer_id: OTHER_CUSTOMER_ID }`
  - Verify: Overridden by RLS (INSERT policy enforces `customer_id = auth.uid()`)
- [ ] **Bug Probe 3:** Admin tries to add another admin
  - Admin tries to set someone else's role = 'admin'
  - Verify: Either blocked, or only Admin can do it (proper RLS)

### 10.10 Hidden Success/Failure Cases
- [ ] **Bug Probe 1:** DB insert succeeds but photo upload fails (partial failure)
  - Mock upload failure while insert succeeds
  - Verify: User shown error, not "success"
  - Verify: Data is consistent (customer created but no photo linked, or photo cleanup attempted)
- [ ] **Bug Probe 2:** Session expires mid-form
  - Fill form, wait 30 min (or mock session expiry), submit
  - Verify: Clear error message about expired session
- [ ] **Bug Probe 3:** Quota exceeded on storage
  - Mock storage quota error
  - Verify: Clear error message, form remains editable for retry
- [ ] **Bug Probe 4:** Foreign key constraint violated
  - Try to create booking with non-existent customer ID
  - Verify: Rejected with clear error (not generic "error")

---

## SUMMARY: GO/NO-GO RELEASE DECISION

Use this template after completing all sections:

```
PROJECT: Veera Rental System
DATE: [TODAY]
RELEASE CANDIDATE: v1.0.0

SECTION 1: VALIDATION
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: All input fields validated, normalized, errors shown

SECTION 2: REQUEST STATUS RULES
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: Pickup/drop-off/swap create correct types, double-submit prevented

SECTION 3: CUSTOMER & VEHICLE LINKING
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: No duplicates, rego lookup reliable, profile edits don't corrupt requests

SECTION 4: FLEET LOGIC
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: Vehicles never double-assigned, swap atomic, counts accurate

SECTION 5: ADMIN AUTHORIZATION
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: RLS enforced, admin roles checked, no permission bypass

SECTION 6: ERROR HANDLING
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: All failure cases show clear messages, no silent failures

SECTION 7: DATA INTEGRITY
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: Constraints, FKs, audit fields all in place and verified

SECTION 8: AUTOMATED TESTS
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: Unit + integration tests passing, ≥80% coverage

SECTION 9: MANUAL REVIEW
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: All workflows tested end-to-end, edge cases verified

SECTION 10: HIDDEN BUG PROBES
  Status: [ ] ✅ PASS [ ] ❌ FAIL
  Notes: Race conditions, authorization abuse, partial failures all caught

OVERALL DECISION:
  [ ] ✅ GO — Release to production
  [ ] 🟡 CONDITIONAL — Fix blocker items, re-test, then release
  [ ] ❌ NO-GO — Major issues found, requires redesign

BLOCKERS (if NO-GO or CONDITIONAL):
  - [ ] ...
  - [ ] ...
  - [ ] ...

SIGN-OFF:
  QA Lead: ________________________ Date: __________
  Tech Lead: ______________________ Date: __________
  Product Owner: __________________ Date: __________
```

---

## NEXT STEPS

1. **Immediate (This Week):**
   - [ ] Complete Sections 1-3 (validation, status rules, customer linking)
   - [ ] Apply `supabase-security-hardening.sql` to Supabase
   - [ ] Execute Section 9 manual review script

2. **Short-term (Next 1-2 Weeks):**
   - [ ] Complete Sections 4-6 (fleet logic, admin auth, error handling)
   - [ ] Implement Section 8 automated tests (unit + integration)
   - [ ] Run Section 10 hidden bug probes

3. **Before Release:**
   - [ ] All 10 sections at ✅ PASS
   - [ ] Fill out GO/NO-GO release decision template
   - [ ] Get sign-off from QA, tech lead, product owner

---

**Document Version:** 1.0  
**Last Updated:** April 19, 2026  
**Maintained By:** Veera Rental System Team  
**Link in README:** Yes (docs/fix-this-first-checklist.md)
