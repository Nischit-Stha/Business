# Business Operations Platform

A combined web platform for:
- **Veera Rentals** (fleet + booking + QR workflow + premium analytics)
- **Veera Food Corner** (multi-page menu + cart + share)

This project is fully static (HTML/CSS/JS) and runs directly from any static host.

## 🎯 Features

### Rentals (`/rentals`) ⭐ Enhanced
- **Admin Dashboard**: Fleet management with availability, maintenance, and utilization stats
- **Advanced Analytics**: Monthly trends, revenue tracking, completed rentals, average rental days
- **Premium Features**:
  - 🎯 **Vehicle Shopping Experience**: Photo gallery, search, sort by price/mileage, favorites
  - 📊 **Compare Tool**: Side-by-side vehicle comparison (up to 5 vehicles)
  - 💰 **Price Range Filter**: Budget-aware vehicle selection
  - ❤️ **Favorites System**: Bookmark and quickly access preferred vehicles
- **Booking Workflow**: Date validation, real-time price calculator, QR code generation
- **Active Rentals List**: With overdue alerts and quick completion action
- **Scanner Portal**: Customer access to pickup/drop-off/swap workflows
- **Service History**: Track all pickups, drop-offs, and vehicle swaps
- **Progress Tracking**: Real-time form completion indicator
- **Export/Reports**: CSV data export and daily business reports
- **Toast Notifications**: Real-time user feedback

### Food (`/food`)
- Multi-page menu: Indian, Pizza/Pasta/Grill, Kebabs
- Interactive cart system
- Call-to-order flow with phone integration
- QR/share link support
- Google Maps location embed
- Mobile-responsive design

### Landing (`/index.html`) ✨ Redesigned
- Premium landing page with service statistics
- Smooth animations and hover effects
- Beautiful gradient design
- Easy navigation to both services

## Project Structure

```text
Business-main/
├── index.html (Enhanced Landing Page)
├── README.md
├── food/
│   ├── index.html
│   ├── pizza-pasta-grill.html
│   ├── kebabs.html
│   ├── script.js
│   ├── style.css
│   └── Menu_Extracted_Content.csv
└── rentals/
    ├── index.html (Admin Dashboard with Premium Stats)
    ├── scanner.html (Service Portal Hub)
    ├── service.html (Pickup/Drop-off with Premium Features)
    ├── customer-booking.html (Customer Portal with Price Calculator)
    ├── app.js (Enhanced with Analytics & Notifications)
    ├── admin-enhanced.js
    ├── style.css
    └── README.md
```

## 🚀 Run Locally

From the project root:

```bash
cd /home/redmoon/Desktop/Business-main
python3 -m http.server 8080
```

Open in browser:
- Landing: `http://localhost:8080/index.html`
- Rentals: `http://localhost:8080/rentals/frontend/index.html`
- Food: `http://localhost:8080/food/index.html`

## 📱 Deploy (GitHub Pages)

1. Push this folder to a GitHub repository.
2. In repository settings, enable **GitHub Pages** from the default branch root.
3. Access pages using:
   - `https://<username>.github.io/<repo>/`
   - `https://<username>.github.io/<repo>/rentals/`
   - `https://<username>.github.io/<repo>/food/`

## 💻 Tech Stack

- HTML5, CSS3, JavaScript (ES6+)
- QRCode.js (CDN)
- Google Maps Embed API
- Browser `localStorage` for client-side persistence
- Picsum.photos for dynamic car images

## ✨ Premium Features Highlights

### Vehicle Shopping
- Browse cars with photos
- Real-time search filtering
- Sort by price or mileage
- Add to favorites for quick access

### Comparison Tools
- Compare up to 5 vehicles side-by-side
- View specs: price, mileage, color, fuel, transmission, seats
- Quick select buttons from comparison modal

### Analytics Dashboard
- Monthly booking trends
- Revenue tracking
- Fleet utilization percentage
- Average rental duration metrics

### Customer Portal
- Real-time price calculation
- Visual vehicle cards with details
- Service history tracking
- Progress indicators

## 📝 Notes

- No backend/database required for local demo
- For production, add authentication + server-side storage
- All data persists in browser localStorage
- Fully responsive design

## 📄 License

Private - All rights reserved.
