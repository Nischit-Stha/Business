# Business Operations Platform

A combined web platform for:
- **Starr365 Rentals** (fleet + booking + QR workflow)
- **Veera Food Corner** (multi-page menu + cart + share)

This project is fully static (HTML/CSS/JS) and runs directly from any static host.

## Features

### Rentals (`/rentals`)
- Fleet dashboard with availability, maintenance, and utilization stats
- Booking workflow with date validation and QR code generation
- Active rentals list with quick completion action
- Scanner and service pages for pickup/drop-off workflow
- Local export/report helpers and browser persistence via `localStorage`

### Food (`/food`)
- Multi-page menu: Indian, Pizza/Pasta/Grill, Kebabs
- Cart + call-to-order flow
- QR/share link support
- Mobile-friendly layout and Google Maps embed

### Landing (`/index.html`)
- Central gateway linking Rentals and Food modules

## Project Structure

```text
Business-main/
├── index.html
├── README.md
├── food/
│   ├── index.html
│   ├── pizza-pasta-grill.html
│   ├── kebabs.html
│   ├── script.js
│   ├── style.css
│   └── Menu_Extracted_Content.csv
└── rentals/
    ├── index.html
    ├── scanner.html
    ├── service.html
    ├── admin.html
    ├── app.js
    ├── admin-enhanced.js
    ├── style.css
    ├── logo.png
    └── README.md
```

## Run Locally

From the project root:

```bash
cd /home/redmoon/Desktop/Business-main
python3 -m http.server 8080
```

Open in browser:
- `http://localhost:8080/index.html`
- `http://localhost:8080/rentals/index.html`
- `http://localhost:8080/food/index.html`

## Deploy (GitHub Pages)

1. Push this folder to a GitHub repository.
2. In repository settings, enable **GitHub Pages** from the default branch root.
3. Access pages using:
   - `https://<username>.github.io/<repo>/`
   - `https://<username>.github.io/<repo>/rentals/`
   - `https://<username>.github.io/<repo>/food/`

## Tech Stack

- HTML5, CSS3, JavaScript (ES6+)
- QRCode.js (CDN)
- Google Maps Embed
- Browser `localStorage` for client-side persistence

## Notes

- No backend/database is required for local demo usage.
- For production business use, add authentication + server-side storage.

## License

Private - All rights reserved.
