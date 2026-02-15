// ===== ADMIN PIN LOCK =====
const ADMIN_PIN = '1234'; // Change this PIN!
let adminUnlocked = false;
let adminAttempts = 0;
const MAX_PIN_ATTEMPTS = 3;
let pinLockTime = null;

// ===== DATA STORAGE =====
let fleet = [
    {
        id: 1,
        name: "Toyota Camry",
        model: "2023",
        status: "available",
        rate: 80,
        rto: 25,
        mileage: 45000,
        fuel: "Full",
        license: "ABC123"
    },
    {
        id: 2,
        name: "Honda Civic",
        model: "2022",
        status: "rented",
        rate: 70,
        rto: 20,
        mileage: 32000,
        fuel: "3/4",
        license: "XYZ789"
    },
    {
        id: 3,
        name: "Mazda CX-5",
        model: "2024",
        status: "available",
        rate: 90,
        rto: 30,
        mileage: 12000,
        fuel: "Full",
        license: "DEF456"
    }
];

let rentalRequests = [];

let rentals = [
    {
        id: 1,
        customer: "John Smith",
        phone: "+61 412 345 678",
        car: "Honda Civic",
        carId: 2,
        pickupDate: new Date("2026-02-14T10:00"),
        returnDate: new Date("2026-02-17T10:00"),
        status: "active"
    }
];

// Load from localStorage if available
function loadData() {
    const savedFleet = localStorage.getItem('starr365-fleet');
    const savedRentals = localStorage.getItem('starr365-rentals');
    const savedRequests = localStorage.getItem('starr365-requests');
    
    if (savedFleet) fleet = JSON.parse(savedFleet);
    if (savedRentals) {
        rentals = JSON.parse(savedRentals);
        // Convert date strings back to Date objects
        rentals = rentals.map(r => ({
            ...r,
            pickupDate: new Date(r.pickupDate),
            returnDate: new Date(r.returnDate)
        }));
    }
    if (savedRequests) {
        rentalRequests = JSON.parse(savedRequests);
        rentalRequests = rentalRequests.map(req => ({
            ...req,
            requestDate: new Date(req.requestDate),
            preferredPickupDate: new Date(req.preferredPickupDate),
            approvedPickupDate: req.approvedPickupDate ? new Date(req.approvedPickupDate) : null
        }));
    }
}

function saveData() {
    localStorage.setItem('starr365-fleet', JSON.stringify(fleet));
    localStorage.setItem('starr365-rentals', JSON.stringify(rentals));
    localStorage.setItem('starr365-requests', JSON.stringify(rentalRequests));
}

// ===== INITIALIZE =====
document.addEventListener('DOMContentLoaded', function() {
    loadData();
    updateStats();
    renderFleet();
    renderRentals();
    populateCarSelect();
    
    // Set up filter buttons
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            filterFleet(this.dataset.filter);
        });
    });
    
    // Set up booking form
    document.getElementById('booking-form').addEventListener('submit', handleNewBooking);
});

// ===== UPDATE STATS =====
function updateStats() {
    const available = fleet.filter(car => car.status === 'available').length;
    const rented = fleet.filter(car => car.status === 'rented').length;
    const maintenance = fleet.filter(car => car.status === 'maintenance').length;
    
    // Calculate today's revenue (simplified)
    const todayRevenue = rentals
        .filter(r => r.status === 'active')
        .reduce((sum, r) => {
            const days = Math.ceil((r.returnDate - r.pickupDate) / (1000 * 60 * 60 * 24));
            const car = fleet.find(c => c.id === r.carId);
            return sum + (car ? car.rate * days : 0);
        }, 0);
    
    document.getElementById('available-count').textContent = available;
    document.getElementById('rented-count').textContent = rented;
    document.getElementById('maintenance-count').textContent = maintenance;
    document.getElementById('revenue-count').textContent = `$${todayRevenue}`;
}

// ===== RENDER FLEET =====
function renderFleet(filter = 'all') {
    const grid = document.getElementById('fleet-grid');
    const filtered = filter === 'all' ? fleet : fleet.filter(car => car.status === filter);
    
    grid.innerHTML = filtered.map(car => `
        <div class="fleet-card" data-id="${car.id}">
            <div class="car-header">
                <div>
                    <div class="car-name">${car.name}</div>
                    <div class="car-model">${car.model}</div>
                </div>
                <span class="status-badge status-${car.status}">
                    ${car.status.charAt(0).toUpperCase() + car.status.slice(1)}
                </span>
            </div>
            <div class="car-details">
                <span>📊 ${car.mileage} km</span>
                <span>⛽ ${car.fuel}</span>
                <span>💰 $${car.rate}/day</span>
            </div>
            <div class="car-details">
                <span>🚗 ${car.license}</span>
            </div>
            <div class="car-actions">
                <button class="btn-small btn-qr" onclick="generateCarQR(${car.id})">
                    📱 Generate QR
                </button>
                <button class="btn-small btn-edit" onclick="editCar(${car.id})">
                    ✏️ Edit
                </button>
            </div>
        </div>
    `).join('');
}

function filterFleet(filter) {
    renderFleet(filter);
}

// ===== RENDER RENTALS =====
function renderRentals() {
    const list = document.getElementById('rentals-list');
    const activeRentals = rentals.filter(r => r.status === 'active');
    
    if (activeRentals.length === 0) {
        list.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No active rentals</p>';
        return;
    }
    
    list.innerHTML = activeRentals.map(rental => {
        const now = new Date();
        const timeUntilReturn = rental.returnDate - now;
        const hoursUntil = Math.floor(timeUntilReturn / (1000 * 60 * 60));
        const isOverdue = timeUntilReturn < 0;
        
        let dueText = '';
        if (isOverdue) {
            dueText = `<span class="overdue">Overdue by ${Math.abs(hoursUntil)}h</span>`;
        } else if (hoursUntil < 2) {
            dueText = `<span class="overdue">Due in ${hoursUntil}h</span>`;
        } else {
            dueText = `<span>Due in ${hoursUntil}h</span>`;
        }
        
        return `
            <div class="rental-card">
                <div class="rental-info">
                    <h4>${rental.customer} - ${rental.car}</h4>
                    <p>${rental.phone}</p>
                </div>
                <div class="rental-meta">
                    <div class="due-time">
                        <strong>Return Time</strong>
                        ${dueText}
                    </div>
                    <button class="btn-small btn-primary" onclick="showRentalDetails(${rental.id})">
                        View Details
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

// ===== MODAL FUNCTIONS =====
function showModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

function showNewBooking() {
    populateCarSelect();
    showModal('booking-modal');
}

function showAddCar() {
    showModal('add-car-modal');
}

// ===== ADD CAR FUNCTIONS =====
function handleAddCar(e) {
    if (e) e.preventDefault();
    
    const carName = document.getElementById('car-name')?.value || prompt('Car Name:');
    const carModel = document.getElementById('car-model')?.value || prompt('Car Model (year):');
    const rate = parseFloat(document.getElementById('car-rate')?.value || prompt('Daily Rate ($):'));
    const rto = parseFloat(document.getElementById('car-rto')?.value || prompt('RTO Fee ($):'));
    const mileage = parseInt(document.getElementById('car-mileage')?.value || prompt('Current Mileage:'));
    const fuel = document.getElementById('car-fuel')?.value || 'Full';
    const license = document.getElementById('car-license')?.value || prompt('License Plate:');
    const color = document.getElementById('car-color')?.value || 'Unknown';
    const vin = document.getElementById('car-vin')?.value || 'N/A';
    
    if (!carName || !carModel || !rate || !license) {
        alert('Please fill in all required fields');
        return;
    }
    
    const newCar = {
        id: Math.max(...fleet.map(c => c.id), 0) + 1,
        name: carName,
        model: carModel,
        status: 'available',
        rate: rate,
        rto: rto || 0,
        mileage: mileage,
        fuel: fuel,
        license: license,
        color: color,
        vin: vin
    };
    
    fleet.push(newCar);
    saveData();
    updateStats();
    renderFleet();
    populateCarSelect();
    populateRequestCarSelect();
    displayAvailableCars();
    
    closeModal('car-modal');
    if (document.getElementById('add-car-form')) {
        document.getElementById('add-car-form').reset();
    }
    
    alert(`✅ Car added successfully!\nID: ${newCar.id}`);
}


function showInspection() {
    alert('Inspection tool - opens at /scanner.html for photo documentation and QR scanning');
}

// ===== DATA EXPORT FUNCTIONS =====
function exportData() {
    const exportObj = {
        exportDate: new Date().toISOString(),
        fleet: fleet,
        rentals: rentals,
        summary: {
            totalCars: fleet.length,
            available: fleet.filter(c => c.status === 'available').length,
            rented: fleet.filter(c => c.status === 'rented').length,
            maintenance: fleet.filter(c => c.status === 'maintenance').length,
            activeRentals: rentals.filter(r => r.status === 'active').length
        }
    };
    
    const dataStr = JSON.stringify(exportObj, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `starr365-export-${new Date().toISOString().split('T')[0]}.json`;
    link.click();
    URL.revokeObjectURL(url);
    
    alert('✅ Data exported successfully!');
}

// ===== DAILY REPORT FUNCTIONS =====
function showDailyReport() {
    const today = new Date();
    const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);
    
    // Calculate today's metrics
    const available = fleet.filter(c => c.status === 'available').length;
    const rented = fleet.filter(c => c.status === 'rented').length;
    const maintenance = fleet.filter(c => c.status === 'maintenance').length;
    
    const todayRentals = rentals.filter(r => 
        (r.pickupDate >= startOfDay && r.pickupDate < endOfDay) ||
        (r.returnDate >= startOfDay && r.returnDate < endOfDay)
    );
    
    const todayRevenue = rentals
        .filter(r => r.status === 'active')
        .reduce((sum, r) => {
            const days = Math.ceil((r.returnDate - r.pickupDate) / (1000 * 60 * 60 * 24));
            const car = fleet.find(c => c.id === r.carId);
            return sum + (car ? car.rate * days : 0);
        }, 0);
    
    const avgRate = fleet.length > 0 
        ? (fleet.reduce((sum, c) => sum + c.rate, 0) / fleet.length).toFixed(2)
        : 0;
    
    const report = `
📊 DAILY REPORT - ${today.toLocaleDateString()}
==========================================

FLEET STATUS
• Total Vehicles: ${fleet.length}
• Available: ${available}
• Rented: ${rented}
• Maintenance: ${maintenance}

TODAY'S ACTIVITY
• Bookings Today: ${todayRentals.length}
• Active Rentals: ${rentals.filter(r => r.status === 'active').length}
• Estimated Revenue: $${todayRevenue}
• Average Daily Rate: $${avgRate}

TOP PERFORMING CARS
${fleet.sort((a, b) => b.rate - a.rate).slice(0, 3).map(c => 
    `• ${c.name} (${c.model}) - $${c.rate}/day`
).join('\n')}
    `;
    
    alert(report);
    
    // Also offer download
    const downloadReport = confirm('Would you like to download this report as a text file?');
    if (downloadReport) {
        const blob = new Blob([report], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `starr365-report-${today.toISOString().split('T')[0]}.txt`;
        link.click();
        URL.revokeObjectURL(url);
    }
}

// ===== QR CODE GENERATION =====
function generateCarQR(carId) {
    const car = fleet.find(c => c.id === carId);
    if (!car) return;
    
    const rental = rentals.find(r => r.carId === carId && r.status === 'active');
    
    const qrData = {
        type: 'car_access',
        carId: car.id,
        carName: car.name,
        license: car.license,
        status: car.status,
        rentalId: rental?.id || null,
        customer: rental?.customer || 'Available for Booking',
        timestamp: new Date().toISOString(),
        scannerUrl: window.location.origin + '/scanner.html'
    };
    
    const qrDisplay = document.getElementById('qr-display');
    qrDisplay.innerHTML = `
        <div id="qr-code-container"></div>
        <p style="margin-top: 1rem; text-align: center; font-size: 0.875rem; color: #6b7280;">
            Vehicle: ${car.name} (${car.license})<br>
            Status: ${car.status.toUpperCase()}
        </p>
    `;
    
    try {
        new QRCode(document.getElementById('qr-code-container'), {
            text: JSON.stringify(qrData),
            width: 256,
            height: 256,
            colorDark: "#111827",
            colorLight: "#ffffff",
            correctLevel: QRCode.CorrectLevel.H
        });
        
        showModal('qr-modal');
    } catch (error) {
        console.error('QR generation failed:', error);
        alert('Failed to generate QR code. Please try again.');
    }
}

function generateQR() {
    if (fleet.length === 0) {
        alert('No cars available. Please add a car first.');
        return;
    }
    generateCarQR(fleet[0].id);
}

// ===== BOOKING FUNCTIONS =====
function populateCarSelect() {
    const select = document.getElementById('car-select');
    const availableCars = fleet.filter(car => car.status === 'available');
    
    select.innerHTML = '<option value="">Choose a car...</option>' +
        availableCars.map(car => 
            `<option value="${car.id}">${car.name} - ${car.model} ($${car.rate}/day + $${car.rto} RTO)</option>`
        ).join('');
}

function handleNewBooking(e) {
    e.preventDefault();
    
    const customerName = document.getElementById('customer-name').value;
    const customerPhone = document.getElementById('customer-phone').value;
    const customerEmail = document.getElementById('customer-email').value;
    const carId = parseInt(document.getElementById('car-select').value);
    const pickupDate = new Date(document.getElementById('pickup-date').value);
    const returnDate = new Date(document.getElementById('return-date').value);
    
    const car = fleet.find(c => c.id === carId);
    if (!car) {
        alert('Please select a car');
        return;
    }
    
    // Create new rental
    const newRental = {
        id: rentals.length + 1,
        customer: customerName,
        phone: customerPhone,
        email: customerEmail,
        car: car.name,
        carId: car.id,
        pickupDate: pickupDate,
        returnDate: returnDate,
        status: 'active'
    };
    
    // Update car status
    car.status = 'rented';
    
    // Add rental
    rentals.push(newRental);
    
    // Save and update
    saveData();
    updateStats();
    renderFleet();
    renderRentals();
    
    // Close modal and reset form
    closeModal('booking-modal');
    document.getElementById('booking-form').reset();
    
    // Generate QR code for this booking
    setTimeout(() => {
        alert(`Booking created successfully!\nBooking ID: ${newRental.id}\n\nQR code will be sent to ${customerEmail}`);
        generateCarQR(carId);
    }, 300);
}

function editCar(carId) {
    const car = fleet.find(c => c.id === carId);
    if (!car) return;
    
    const newStatus = prompt(`Update status for ${car.name}:\n\navailable / rented / maintenance`, car.status);
    
    if (newStatus && ['available', 'rented', 'maintenance'].includes(newStatus)) {
        car.status = newStatus;
        saveData();
        updateStats();
        renderFleet();
        renderRentals();
    }
}

function showRentalDetails(rentalId) {
    const rental = rentals.find(r => r.id === rentalId);
    if (!rental) return;
    
    const car = fleet.find(c => c.id === rental.carId);
    const days = Math.ceil((rental.returnDate - rental.pickupDate) / (1000 * 60 * 60 * 24));
    const total = car ? car.rate * days : 0;
    
    alert(`Rental Details:\n\n` +
          `Customer: ${rental.customer}\n` +
          `Phone: ${rental.phone}\n` +
          `Car: ${rental.car}\n` +
          `Pickup: ${rental.pickupDate.toLocaleString()}\n` +
          `Return: ${rental.returnDate.toLocaleString()}\n` +
          `Days: ${days}\n` +
          `Total: $${total}\n\n` +
          `QR actions available for pickup/dropoff`);
}

// ===== AUTO REFRESH =====
// Update time-sensitive displays every minute
setInterval(() => {
    renderRentals();
}, 60000);

// ===== PIN LOCK FUNCTIONS =====
function checkPinLockStatus() {
    if (pinLockTime && Date.now() - pinLockTime < 300000) { // 5 minute lockout
        const remainingTime = Math.ceil((300000 - (Date.now() - pinLockTime)) / 1000);
        return { locked: true, message: `Too many attempts. Try again in ${remainingTime}s` };
    }
    pinLockTime = null;
    return { locked: false };
}

function verifyAdminPin(pin) {
    const lockStatus = checkPinLockStatus();
    if (lockStatus.locked) {
        alert(lockStatus.message);
        return false;
    }
    
    if (pin === ADMIN_PIN) {
        adminUnlocked = true;
        adminAttempts = 0;
        pinLockTime = null;
        localStorage.setItem('starr365-admin-unlocked', 'true');
        toggleAdminMode();
        closeModal('pin-modal');
        return true;
    } else {
        adminAttempts++;
        if (adminAttempts >= MAX_PIN_ATTEMPTS) {
            pinLockTime = Date.now();
            alert('Too many incorrect attempts. Admin locked for 5 minutes.');
            return false;
        }
        alert(`Wrong PIN. ${MAX_PIN_ATTEMPTS - adminAttempts} attempts remaining.`);
        return false;
    }
}

function toggleAdminMode() {
    const adminSections = document.querySelectorAll('.admin-only');
    const customerSections = document.querySelectorAll('.customer-only');
    
    if (adminUnlocked) {
        adminSections.forEach(el => el.style.display = 'block');
        customerSections.forEach(el => el.style.display = 'none');
    } else {
        adminSections.forEach(el => el.style.display = 'none');
        customerSections.forEach(el => el.style.display = 'block');
    }
}

function logoutAdmin() {
    adminUnlocked = false;
    adminAttempts = 0;
    localStorage.removeItem('starr365-admin-unlocked');
    toggleAdminMode();
    alert('Admin mode logged out');
}

// ===== RENTAL REQUEST FUNCTIONS =====
function submitRentalRequest(e) {
    e.preventDefault();
    
    const name = document.getElementById('req-name').value;
    const phone = document.getElementById('req-phone').value;
    const email = document.getElementById('req-email').value;
    const carId = parseInt(document.getElementById('req-car-select').value);
    const pickupDate = new Date(document.getElementById('req-pickup-date').value);
    const notes = document.getElementById('req-notes').value;
    
    const car = fleet.find(c => c.id === carId);
    if (!car || car.status !== 'available') {
        alert('Selected car is no longer available');
        return;
    }
    
    const request = {
        id: Date.now(),
        name,
        phone,
        email,
        carId,
        carName: car.name,
        requestDate: new Date(),
        preferredPickupDate: pickupDate,
        notes,
        status: 'pending',
        approvedPickupDate: null
    };
    
    rentalRequests.push(request);
    saveData();
    
    alert(`Request submitted successfully!\n\nWe will review your request and contact you at ${phone} to confirm your pickup time.`);
    document.getElementById('request-form').reset();
    closeModal('request-modal');
    loadData();
}

function approveRequest(requestId) {
    const request = rentalRequests.find(r => r.id === requestId);
    if (!request) return;
    
    const timeStr = prompt('Approve this request. Enter pickup time (HH:MM):', '10:00');
    if (!timeStr) return;
    
    const [hours, minutes] = timeStr.split(':').map(Number);
    if (isNaN(hours) || isNaN(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
        alert('Invalid time format. Use HH:MM');
        return;
    }
    
    const approvedDate = new Date(request.preferredPickupDate);
    approvedDate.setHours(hours, minutes, 0, 0);
    
    request.status = 'approved';
    request.approvedPickupDate = approvedDate;
    
    const car = fleet.find(c => c.id === request.carId);
    car.status = 'rented';
    
    const rental = {
        id: Date.now(),
        customer: request.name,
        phone: request.phone,
        email: request.email,
        car: car.name,
        carId: car.id,
        pickupDate: approvedDate,
        returnDate: new Date(approvedDate.getTime() + 3 * 24 * 60 * 60 * 1000), // Default 3 days
        status: 'approved',
        requestId: requestId,
        rentalRate: car.rate,
        rto: car.rto
    };
    
    rentals.push(rental);
    saveData();
    
    alert(`Request approved!\n\nCustomer will pick up ${car.name} on ${approvedDate.toLocaleString()}`);
    renderAdminRequests();
    updateStats();
    renderFleet();
}

function denyRequest(requestId) {
    const request = rentalRequests.find(r => r.id === requestId);
    if (!request) return;
    
    const reason = prompt('Reason for denial:', '');
    
    request.status = 'denied';
    request.denialReason = reason;
    saveData();
    
    alert(`Request denied. Customer will not be contacted.`);
    renderAdminRequests();
}

function renderAdminRequests() {
    const container = document.getElementById('admin-requests');
    if (!container) return;
    
    const pendingRequests = rentalRequests.filter(r => r.status === 'pending');
    
    if (pendingRequests.length === 0) {
        container.innerHTML = '<p style="text-align: center; color: #999;">No pending requests</p>';
        return;
    }
    
    container.innerHTML = pendingRequests.map(req => `
        <div style="border: 1px solid #ddd; padding: 15px; margin-bottom: 10px; border-radius: 8px;">
            <h4>${req.name}</h4>
            <p><strong>Car:</strong> ${req.carName}</p>
            <p><strong>Phone:</strong> ${req.phone}</p>
            <p><strong>Email:</strong> ${req.email}</p>
            <p><strong>Preferred Pickup:</strong> ${req.preferredPickupDate.toLocaleString()}</p>
            <p><strong>Notes:</strong> ${req.notes || 'None'}</p>
            <div style="margin-top: 10px;">
                <button class="btn btn-primary" onclick="approveRequest(${req.id})" style="margin-right: 5px;">✓ Approve</button>
                <button class="btn btn-danger" onclick="denyRequest(${req.id})">✗ Deny</button>
            </div>
        </div>
    `).join('');
}

function renderServiceLogs() {
    const container = document.getElementById('service-logs');
    if (!container) return;

    const pickups = JSON.parse(localStorage.getItem('starr365-pickups') || '[]');
    const dropoffs = JSON.parse(localStorage.getItem('starr365-dropoffs') || '[]');
    const swaps = JSON.parse(localStorage.getItem('starr365-swaps') || '[]');

    const logs = [
        ...pickups.map(item => ({ type: 'Pickup', data: item })),
        ...dropoffs.map(item => ({ type: 'Drop-off', data: item })),
        ...swaps.map(item => ({ type: 'Swap', data: item }))
    ].sort((a, b) => new Date(b.data.timestamp) - new Date(a.data.timestamp));

    if (logs.length === 0) {
        container.innerHTML = '<p style="text-align: center; color: #999;">No service logs yet</p>';
        return;
    }

    container.innerHTML = logs.map(entry => {
        const time = entry.data.timestamp ? new Date(entry.data.timestamp).toLocaleString() : 'N/A';
        const refId = entry.data.serviceRefId || 'N/A';

        if (entry.type === 'Pickup') {
            return `
                <div style="border: 1px solid #ddd; padding: 15px; margin-bottom: 10px; border-radius: 8px;">
                    <h4>🔑 Pickup</h4>
                    <p><strong>Ref ID:</strong> ${refId}</p>
                    <p><strong>Customer:</strong> ${entry.data.name}</p>
                    <p><strong>Vehicle:</strong> ${entry.data.vehicle}</p>
                    <p><strong>Mileage:</strong> ${entry.data.mileage} km</p>
                    <p><strong>Fuel:</strong> ${entry.data.fuel}</p>
                    <p><strong>Condition:</strong> ${entry.data.condition}</p>
                    <p><strong>Time:</strong> ${time}</p>
                </div>
            `;
        }

        if (entry.type === 'Drop-off') {
            return `
                <div style="border: 1px solid #ddd; padding: 15px; margin-bottom: 10px; border-radius: 8px;">
                    <h4>🗝️ Drop-off</h4>
                    <p><strong>Ref ID:</strong> ${refId}</p>
                    <p><strong>Customer:</strong> ${entry.data.name}</p>
                    <p><strong>Vehicle:</strong> ${entry.data.vehicle}</p>
                    <p><strong>Rego:</strong> ${entry.data.rego || 'N/A'}</p>
                    <p><strong>Mileage:</strong> ${entry.data.mileage} km</p>
                    <p><strong>Fuel:</strong> ${entry.data.fuel}</p>
                    <p><strong>Condition:</strong> ${entry.data.condition}</p>
                    <p><strong>Notes:</strong> ${entry.data.notes || 'None'}</p>
                    <p><strong>Time:</strong> ${time}</p>
                </div>
            `;
        }

        return `
            <div style="border: 1px solid #ddd; padding: 15px; margin-bottom: 10px; border-radius: 8px;">
                <h4>🔄 Swap</h4>
                <p><strong>Ref ID:</strong> ${refId}</p>
                <p><strong>Customer:</strong> ${entry.data.name}</p>
                <p><strong>Current Vehicle:</strong> ${entry.data.currentVehicle}</p>
                <p><strong>Current Mileage:</strong> ${entry.data.currentMileage} km</p>
                <p><strong>Current Fuel:</strong> ${entry.data.currentFuel}</p>
                <p><strong>Condition:</strong> ${entry.data.currentCondition}</p>
                <p><strong>New Vehicle:</strong> ${entry.data.newVehicle}</p>
                <p><strong>Reason:</strong> ${entry.data.reason}</p>
                <p><strong>Notes:</strong> ${entry.data.notes || 'None'}</p>
                <p><strong>Time:</strong> ${time}</p>
            </div>
        `;
    }).join('');
}
