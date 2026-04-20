# Rentals Module

Frontend for the Veera Rentals request workflow. The current model is request-driven and uses Supabase as the system of record for both operational requests and normalized customer profiles.

## Main Screens

- [frontend/admin.html](frontend/admin.html): canonical admin dashboard shell and navigation
- [frontend/index.html](frontend/index.html): legacy entry that redirects to admin login/dashboard
- [frontend/admin-enhanced.js](frontend/admin-enhanced.js): request, customer, fleet, and report rendering
- [frontend/service.html](frontend/service.html): pickup, drop-off, and swap request form
- [frontend/service-details.html](frontend/service-details.html): confirmation page after submit
- [frontend/customer-booking.html](frontend/customer-booking.html): customer-facing booking entry point
- [frontend/scanner.html](frontend/scanner.html): operational service hub

## Current Workflow

1. Pickup request captures name, phone, email, driver license details, vehicle choice, budget, and photo links.
2. The form saves a normalized customer record, then stores the booking request.
3. Drop-off and swap flows look up the latest booking by rego, phone, and email when needed.
4. Admin views split requests into pickup, drop-off, and swap sections.
5. Customer records show current vehicle, last request type, license photo URLs, and booking history.

## Data Used

- `vehicles`: fleet inventory
- `booking_requests`: operational request log
- `customers`: normalized customer profiles
- `invoices`: billing history
- `offers`, `offer_messages`, `payment_intents`: supporting business records

## Developer Notes

- Keep request-only data in `booking_requests` and customer profile data in `customers`.
- Update `frontend/service.html` and `frontend/admin-enhanced.js` together when adding or renaming request fields.
- Update `supabase-setup-final.sql` before relying on new customer columns in the UI.
- The canonical source tree is `Business-main/...`; `Desktop/Business-main/...` is the mirrored legacy path.
