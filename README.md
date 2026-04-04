# Business Operations Platform

Static HTML/CSS/JS workspace for two public sites:
- `food/` for the menu site
- `rentals/frontend/` for the Veera Rentals app

The canonical rentals code lives under `Business-main/...`. There is also a legacy mirror under `Desktop/Business-main/...`; update the `Business-main` copy first when making changes.

## Rentals Overview

The rentals app is split into three roles:
- Customer booking and service requests
- Admin booking/request review
- Fleet and customer record management

### Request Types
- Pickup: customer selects a vehicle and submits name, phone, email, license photos, and budget
- Drop-off: admin/customer lookup by rego plus phone/email, then submits return photos and mileage
- Swap: same request flow as drop-off, with the swap request recorded for admin review

### Admin Views
- `Requests` tab: pickup, drop-off, and swap requests
- `Customers` tab: saved customer records, current vehicle, request type, license photos, booking history
- `Fleet` tab: car-only inventory and availability

## Important Files

### Rentals frontend
- [rentals/frontend/service.html](rentals/frontend/service.html): pickup/drop-off/swap request form
- [rentals/frontend/service-details.html](rentals/frontend/service-details.html): post-submit confirmation page
- [rentals/frontend/admin.html](rentals/frontend/admin.html): admin shell and navigation
- [rentals/frontend/admin-enhanced.js](rentals/frontend/admin-enhanced.js): request/customer/fleet rendering
- [rentals/frontend/app.js](rentals/frontend/app.js): core rental logic and reports

### Database bootstrap
- [supabase-setup-final.sql](supabase-setup-final.sql): creates customers, links customer IDs, and enables app-access policies

## Data Model

The rentals app stores:
- `vehicles`: fleet inventory
- `booking_requests`: pickup and service requests
- `customers`: normalized customer records
- `invoices`: billing records
- `offers`, `offer_messages`, `payment_intents`: supporting business flow

Customer records are normalized around:
- full name
- phone
- email
- current vehicle
- last request type
- license photo URLs

## Local Run

From the project root:

```powershell
cd C:\Users\Nischit\Desktop\Business-main
python -m http.server 8080
```

Open:
- Landing: `http://localhost:8080/index.html`
- Rentals: `http://localhost:8080/rentals/frontend/index.html`
- Admin: `http://localhost:8080/rentals/frontend/admin.html`
- Service form: `http://localhost:8080/rentals/frontend/service.html`

## Developer Notes

- Keep request-only data in `booking_requests` and customer profile data in `customers`
- Update both the service form and admin renderer when adding new request fields
- The `Business-main` path is the one to use for GitHub updates
- For Supabase changes, update `supabase-setup-final.sql` before editing UI assumptions

## Food Site

The food site is a separate static app under `food/` with its own HTML, CSS, and JS files.
