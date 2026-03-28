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
- Mileage, fuel level
- Daily rate

### Bookings
- Customer info
- Pickup/return dates
- Car assigned
- Status

### Inspections
- Photos (4+ per inspection)
- Odometer readings
- Fuel levels
- GPS coordinates
- Timestamps
- Notes/damage reports

## 🚀 Next Steps to Build

1. **Backend Integration**
   - Replace localStorage with database
   - API for saving data

2. **SMS/Email Automation**
   - Send QR codes via Twilio
   - Booking confirmations
   - Reminders

3. **Payment Integration**
   - Link to Payd
   - Auto-charge late fees
   - Fuel refunds

4. **Advanced Features**
   - Maintenance scheduler
   - Customer history
   - Revenue reports
   - Damage claim workflow
   - Insurance integration

## 💡 Usage Tips

- **QR Codes**: Generate unique QR for each booking ID
- **Photos**: Require minimum 4 photos (F/B/I/F)
- **Disputes**: Before/after photos = legal proof
- **Fuel**: Photo of gauge = no arguments
- **GPS**: Proves pickup/dropoff location
- **Timestamps**: Cannot be manipulated

## 🔐 Security

- Customer data in localStorage (browser only)
- For production: Use proper database + auth
- QR codes can include encrypted booking ID
- GPS & timestamps prevent fraud

## 📱 Mobile Friendly

- Fully responsive design
- Camera access for photos
- GPS location capture
- Works on any smartphone

---

**Built for Veera Rentals**
*Automating inspections, tracking, and customer experience*
