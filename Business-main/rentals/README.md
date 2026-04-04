# Veera Rentals Management System

## 🚗 Features

### Admin Dashboard (`index.html`)
- **Real-time Fleet Overview**: See all cars at a glance
- **Stats Dashboard**: Available, Rented, Maintenance, Revenue
- **Quick Actions**: New booking, Add car, Generate QR
- **Active Rentals Tracking**: See due times, overdue alerts
- **QR Code Generation**: Unique QR for each car/booking

### Customer Scanner (`scanner.html`)
- **Pickup/Dropoff Inspection**: Photo documentation
- **Odometer & Fuel Logging**: Automatic timestamping
- **GPS Location**: Auto-capture location
- **Photo Evidence**: Front, back, interior, fuel gauge
- **Notes System**: Report damages or issues

## 📱 How It Works

### 1. Create a Booking
1. Click "New Booking" on dashboard
2. Enter customer details
3. Select car and dates
4. System auto-generates QR code
5. QR sent to customer via SMS/email

### 2. Customer Pickup (QR Scan)
1. Customer scans QR code → Opens `scanner.html`
2. Takes photos (4 angles + fuel gauge)
3. Logs odometer reading
4. Confirms fuel level
5. Adds any notes
6. Submits → Timestamped with GPS

### 3. Customer Dropoff (QR Scan)
1. Customer scans same QR at return
2. Switches to "Dropoff" mode
3. Takes new photos
4. Logs final odometer
5. Confirms fuel returned
6. System calculates:
   - Miles driven
   - Fuel difference
   - Extra charges
   - Generates invoice

### 4. Admin Reviews
- Compare pickup vs dropoff photos
- Verify odometer readings
- Check fuel levels
- Review any damage claims
- All data timestamped & GPS-tagged

## 🔧 Setup

### Local Testing
1. Open `index.html` in browser
2. Add cars, create bookings
3. Generate QR codes
4. Test scanner with `scanner.html`

### Going Live
Upload all files to your hosting:
```
/veera-rentals/
  ├── index.html      (Admin dashboard)
  ├── scanner.html    (Customer QR scanner)
  ├── style.css       (Styles)
  └── app.js          (Logic)
```

## 🎯 Key Automations

✅ **Auto QR Generation**: Each booking gets unique QR
✅ **Photo Documentation**: Timestamped proof
✅ **GPS Tracking**: Location of pickup/dropoff
✅ **Time Tracking**: Automatic late fee calculation
✅ **Fuel Monitoring**: Before/after comparison
✅ **Mileage Logging**: Automatic calculation
✅ **Status Updates**: Real-time availability
✅ **LocalStorage**: Data persists in browser

## 📊 Data Stored

### Fleet
- Car details (make, model, license)
- Current status (available/rented/maintenance)
# Rentals Module

Frontend for the Veera Rentals request workflow. The current model is request-driven and uses Supabase as the system of record for both operational requests and normalized customer profiles.

## Main Screens

- [frontend/index.html](frontend/index.html): admin dashboard entry
- [frontend/admin.html](frontend/admin.html): admin shell and navigation
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
   - Revenue reports
