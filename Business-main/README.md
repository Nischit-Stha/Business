# 🚀 Business Operations Platform

Complete online solution for **Starr365 Car Rental** and **Veera Food Corner** management.

## 📋 Contents

- **🚗 `/rentals`** - Starr365 Car Rental System
  - Admin dashboard with fleet management
  - QR code-based check-in/out process
  - Real-time booking system
  - Daily reports and analytics
  
- **🍽️ `/food`** - Veera Food Corner Menu
  - Indian cuisine specialties
  - Pizza, pasta & grill options
  - Kebabs menu
  - Online ordering interface
  - Google Maps integration

- **🏠 `/public`** - Landing page with access portal

## 🌐 Live URLs

Once deployed on GitHub Pages, access at:

```
https://yourusername.github.io/business-online/
https://yourusername.github.io/business-online/rentals
https://yourusername.github.io/business-online/food
```

## 🚀 Quick Start (Local)

### Start both servers:
```bash
cd ~/Desktop/website && python3 -m http.server 8000 &
cd ~/Desktop/starr365-rental && python3 -m http.server 8080 &
```

### Access locally:
- Main: http://localhost:8080
- Rentals: http://localhost:8080
- Food: http://localhost:8000

### Stop servers:
```bash
pkill -f "http.server"
```

## 📦 Features

### Starr365 Car Rental
- ✅ Fleet management (add/edit vehicles)
- ✅ Real-time booking system
- ✅ QR code generation for pickups
- ✅ Customer scanner app
- ✅ Daily revenue reports
- ✅ Data export (JSON)
- ✅ localStorage persistence

### Veera Food Corner
- ✅ 3-page menu system
- ✅ Shopping cart
- ✅ QR sharing
- ✅ Google Maps location
- ✅ Responsive design
- ✅ Mobile-friendly

## 🔧 Tech Stack

- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **Storage**: Browser localStorage
- **QR Code**: QRCode.js library
- **Maps**: Google Maps Embed API
- **Styling**: Modern CSS with gradients & animations
- **Responsive**: Mobile-first design

## 📱 Browser Support

- Chrome/Chromium ✅
- Firefox ✅
- Safari ✅
- Edge ✅
- Mobile browsers ✅

## 🔐 Security

- No backend database needed
- All data stored locally in browser
- HTTPS/SSL on GitHub Pages
- No sensitive data exposed

## 📝 License

Private - All rights reserved

## 👨‍💼 Owner

Nischit-stha

---

**Last Updated:** February 15, 2026
