# 📚 Code Overview - Business Systems

## Repository: `Nischit-stha/business`
**GitHub URL:** https://github.com/Nischit-stha/business

---

## 🚗 STARR365 CAR RENTAL SYSTEM

### Location: `/rentals/`

#### Files:
- **index.html** (301 lines) - Admin Dashboard
- **app.js** (510 lines) - Core application logic
- **scanner.html** (225 lines) - Customer QR Scanner
- **style.css** - Professional styling
- **README.md** - Documentation

#### Key Features:

**Data Storage (app.js)**
```javascript
let fleet = [
  { id: 1, name: "Toyota Camry", model: "2023", status: "available", 
    rate: 80, mileage: 45000, fuel: "Full", license: "ABC123" },
  // ... more cars
];

let rentals = [
  { id: 1, customer: "John Smith", phone: "+61 412 345 678", 
    car: "Honda Civic", carId: 2, status: "active" },
  // ... more bookings
];
```

**Main Functions:**
1. `loadData()` - Load from localStorage
2. `saveData()` - Save to localStorage
3. `updateStats()` - Calculate available/rented/maintenance counts
4. `renderFleet(filter)` - Display all vehicles
5. `renderRentals()` - Show active bookings
6. `handleNewBooking(e)` - Process new reservations
7. `handleAddCar(e)` - Add new vehicle to fleet
8. `generateCarQR(carId)` - Create QR codes for pickups
9. `exportData()` - Download fleet data as JSON
10. `showDailyReport()` - Generate revenue reports

**Statistics Tracking:**
- Available vehicles count
- Rented vehicles count
- Under maintenance count
- Daily revenue calculation
- Fleet utilization percentage

**QR Code Generation:**
```javascript
const qrData = {
  type: 'car_access',
  carId: car.id,
  carName: car.name,
  license: car.license,
  status: car.status,
  rentalId: rental?.id,
  timestamp: new Date().toISOString()
};
```

**Forms:**
- New Booking Form (customer name, phone, email, dates, car selection)
- Add Vehicle Form (name, model, rate, license, mileage, fuel, color, VIN)

---

## 🍽️ VEERA FOOD CORNER

### Location: `/food/`

#### Files:
- **index.html** (121 lines) - Main Indian menu page
- **pizza-pasta-grill.html** (117 lines) - Pizza & Pasta menu
- **kebabs.html** (117 lines) - Kebabs menu
- **script.js** (1253 lines) - Menu & cart logic
- **style.css** - Responsive styling
- **Menu_Extracted_Content.csv** - Menu data source
- **style/** - Additional stylesheets
- **images/** - Menu item images

#### Menu Structure:
```javascript
const menuData = {
  indian: [
    // VEG SNACKS
    { name: "Papri Chat", desc: "Veg Snacks", price: "$8.99", img: "..." },
    { name: "Spring Roll", desc: "Veg Snacks", price: "$8.99", img: "..." },
    { name: "Noodles", desc: "Veg Snacks", price: "$9.99", img: "..." },
    // ... 50+ items
  ],
  nonveg: [
    // NON-VEG items
  ]
};
```

#### Key Functions:

**Menu Management:**
1. `renderMenu(category)` - Display items by category
2. `handleMenuGridClick(event)` - Handle item selection
3. `populatePizzaMenuFromCsv()` - Load pizza menu from CSV
4. `buildCsvDescription(row)` - Parse CSV data
5. `getImageForCategory(category)` - Auto-select food images

**Cart Operations:**
1. `addToCart(item)` - Add item to shopping cart
2. `removeCartItem(name)` - Remove item from cart
3. `clearCart()` - Empty entire cart
4. `renderCart()` - Display cart contents
5. `handleCartCheckout()` - Process order

**Storage & Sharing:**
1. `loadCartFromStorage()` - Load cart from localStorage
2. `saveCartToStorage()` - Persist cart data
3. `copyLink()` - Share menu via QR/link
4. `setActiveButton(category)` - Update UI state

**Parsing & Formatting:**
- `parseCsv(text)` - CSV parsing
- `extractPriceValue(priceText)` - Price extraction
- `formatCurrency(amount)` - Format prices
- `escapeAttribute(value)` - XSS prevention

#### Menu Categories:
- VEG SNACKS (8 items)
- MAIN COURSE - VEG (10+ items)
- MAIN COURSE - NON-VEG (10+ items)
- BIRYANIS (5 items)
- DRINKS (5 items)
- PIZZA & PASTA (from CSV)
- KEBABS (from separate page)

---

## 🏠 LANDING PAGE

### Location: `/public/index.html`

**Features:**
- Welcome message
- Quick access buttons to both systems
- Service descriptions
- Feature highlights
- Responsive design for mobile/desktop

---

## 🔧 TECHNICAL STACK

### Frontend Technologies:
- **HTML5** - Semantic markup
- **CSS3** - Flexbox, Grid, Gradients, Animations
- **JavaScript (ES6+)** - Modern async/await, arrow functions
- **QRCode.js** - QR code generation
- **Google Maps Embed API** - Location tracking
- **Google Fonts** - Inter, Poppins typography

### Data Storage:
```javascript
// localStorage Keys:
- starr365-fleet      // Vehicle list
- starr365-rentals    // Booking history
- veera-cart          // Shopping cart
```

### API Integrations:
- Google Maps (embedded iframes)
- Google Fonts (CDN)
- Unsplash (image URLs)
- QRCode.js library

---

## 📊 DATA FLOW

### Starr365:
```
[Admin Dashboard] → [app.js] → [localStorage] → [QR Generation] → [Customer Scanner]
                ↓
        [Fleet Management]
        [Booking Creation]
        [Data Export]
        [Daily Reports]
```

### Veera Food:
```
[Menu Pages] → [script.js] → [Shopping Cart] → [localStorage] → [QR Share Link]
           ↓
   [CSV Data Import]
   [Menu Rendering]
   [Item Selection]
   [Order Processing]
```

---

## 🚀 DEPLOYMENT INFO

**GitHub Repository:** https://github.com/Nischit-stha/business

**GitHub Pages URLs:**
- Main: https://nischit-stha.github.io/business/
- Rentals: https://nischit-stha.github.io/business/rentals
- Food: https://nischit-stha.github.io/business/food

**Routing Configuration (netlify.toml):**
```toml
[[redirects]]
  from = "/rentals/*"
  to = "/rentals/index.html"
  status = 200

[[redirects]]
  from = "/food/*"
  to = "/food/index.html"
  status = 200
```

---

## 📦 FILE STRUCTURE

```
business/
├── public/
│   └── index.html              ← Landing page
├── rentals/
│   ├── index.html              ← Admin dashboard
│   ├── scanner.html            ← Customer app
│   ├── app.js                  ← Core logic (510 lines)
│   ├── style.css               ← Styling
│   └── README.md               ← Documentation
├── food/
│   ├── index.html              ← Main menu
│   ├── pizza-pasta-grill.html  ← Pizza menu
│   ├── kebabs.html             ← Kebabs menu
│   ├── script.js               ← Logic (1253 lines)
│   ├── style.css               ← Styling
│   ├── Menu_Extracted_Content.csv
│   ├── images/                 ← Food photos
│   └── ... (more files)
├── README.md                   ← Main docs
└── netlify.toml               ← Routing config
```

---

## 💾 LOCAL TESTING

Start both systems locally:
```bash
# Terminal 1 - Rental System
cd ~/Desktop/starr365-rental
python3 -m http.server 8080

# Terminal 2 - Food System
cd ~/Desktop/website
python3 -m http.server 8000
```

Access at:
- http://localhost:8080 (Rentals)
- http://localhost:8000 (Food)
- http://localhost:8080 (Portal)

---

## 🔐 Security & Privacy

- ✅ No backend server needed
- ✅ All data stored locally in browser
- ✅ HTTPS/SSL on GitHub Pages
- ✅ No user data exposed
- ✅ No third-party tracking
- ✅ Responsive to XSS attacks

---

**Last Updated:** February 15, 2026
**Repository:** github.com/Nischit-stha/business
**Status:** ✅ Live on GitHub Pages
