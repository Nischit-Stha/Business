// ===== DATA STORAGE =====
let fleet = [];

let rentals = [];

function normalizeRentalDates(rentalList = []) {
    return rentalList.map(r => ({
        ...r,
        pickupDate: new Date(r.pickupDate),
        returnDate: new Date(r.returnDate)
    }));
}

async function importSeedDataFromRecords() {
    const response = await fetch('records-seed.json', { cache: 'no-store' });
    if (!response.ok) {
        throw new Error('Seed file unavailable');
    }

    const seedData = await response.json();
    if (Array.isArray(seedData.fleet) && seedData.fleet.length > 0) {
        fleet = seedData.fleet;
    }
    if (Array.isArray(seedData.rentals) && seedData.rentals.length > 0) {
        rentals = normalizeRentalDates(seedData.rentals);
    }

    saveData();
    localStorage.setItem('records-imported-v1', 'true');
}

async function reimportFromRecords() {
    const confirmed = window.confirm('Re-importing will replace current fleet and rental data with Records seed data. Continue?');
    if (!confirmed) {
        return;
    }

    try {
        await importSeedDataFromRecords();
        updateStats();
        renderFleet();
        renderRentals();
        renderServiceHistory();
        populateCarSelect();
        showToast('Records data re-imported successfully.', 'success');
    } catch (error) {
        console.error('Re-import failed:', error);
        showToast('Re-import failed. Please check records-seed.json.', 'error');
    }
}

// Load from localStorage if available
async function loadData() {
    const savedFleet = localStorage.getItem('fleet-data');
    const savedRentals = localStorage.getItem('rentals-data');
    const importedFlag = localStorage.getItem('records-imported-v1') === 'true';

    if (!importedFlag) {
        try {
            await importSeedDataFromRecords();
            return;
        } catch (error) {
            console.warn('Could not import Records seed data:', error);
        }
    }

    if (savedFleet) {
        fleet = JSON.parse(savedFleet);
    }
    if (savedRentals) {
        rentals = normalizeRentalDates(JSON.parse(savedRentals));
    }
}

function saveData() {
    localStorage.setItem('fleet-data', JSON.stringify(fleet));
    localStorage.setItem('rentals-data', JSON.stringify(rentals));
}

function showToast(message, type = 'info') {
    if (!document.getElementById('toast-styles')) {
        const style = document.createElement('style');
        style.id = 'toast-styles';
        style.textContent = `
            #toast-container {
                position: fixed;
                top: 1rem;
                right: 1rem;
                z-index: 9999;
                display: flex;
                flex-direction: column;
                gap: 0.75rem;
            }
            .app-toast {
                min-width: 260px;
                max-width: 360px;
                padding: 0.85rem 1rem;
                border-radius: 0.75rem;
                color: #ffffff;
                font-weight: 600;
                box-shadow: 0 10px 25px rgba(0, 0, 0, 0.25);
                opacity: 0;
                transform: translateY(-8px);
                transition: all 0.22s ease;
            }
            .app-toast.show {
                opacity: 1;
                transform: translateY(0);
            }
            .app-toast.info { background: #2563eb; }
            .app-toast.success { background: #059669; }
            .app-toast.warning { background: #d97706; }
            .app-toast.error { background: #dc2626; }
        `;
        document.head.appendChild(style);
    }

    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `app-toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    requestAnimationFrame(() => toast.classList.add('show'));

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 220);
    }, 3200);
}

function formatDateTimeLocal(date) {
    const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
    return local.toISOString().slice(0, 16);
}

function initializeBookingDateInputs() {
    const pickupInput = document.getElementById('pickup-date');
    const returnInput = document.getElementById('return-date');
    if (!pickupInput || !returnInput) return;

    const now = new Date();
    pickupInput.min = formatDateTimeLocal(now);

    const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    if (!pickupInput.value) {
        pickupInput.value = formatDateTimeLocal(now);
    }
    returnInput.min = formatDateTimeLocal(twoHoursFromNow);
    if (!returnInput.value) {
        returnInput.value = formatDateTimeLocal(twoHoursFromNow);
    }

    pickupInput.onchange = () => {
        const pickupDate = new Date(pickupInput.value);
        if (Number.isNaN(pickupDate.getTime())) return;
        const minReturnDate = new Date(pickupDate.getTime() + 60 * 60 * 1000);
        returnInput.min = formatDateTimeLocal(minReturnDate);
        if (!returnInput.value || new Date(returnInput.value) <= pickupDate) {
            returnInput.value = formatDateTimeLocal(minReturnDate);
        }
    };
}

function setActiveNavLink(targetId) {
    document.querySelectorAll('.nav-link').forEach(link => {
        const isActive = link.getAttribute('href') === `#${targetId}`;
        link.classList.toggle('active', isActive);
    });
}

function initializeNavLinks() {
    const navLinks = document.querySelectorAll('.nav-link');
    if (!navLinks.length) return;

    navLinks.forEach(link => {
        link.addEventListener('click', (event) => {
            event.preventDefault();
            const targetHash = link.getAttribute('href');
            if (!targetHash || !targetHash.startsWith('#')) return;

            const targetId = targetHash.slice(1);
            const targetSection = document.getElementById(targetId);
            if (!targetSection) return;

            targetSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
            setActiveNavLink(targetId);
            window.history.replaceState(null, '', targetHash);
        });
    });

    const initialHash = window.location.hash?.replace('#', '');
    const initialTarget = initialHash && document.getElementById(initialHash) ? initialHash : 'dashboard';
    setActiveNavLink(initialTarget);
}

// ===== INITIALIZE =====
document.addEventListener('DOMContentLoaded', async function() {
    await loadData();
    updateStats();
    renderFleet();
    renderRentals();
    renderServiceHistory();
    populateCarSelect();
    initializeBookingDateInputs();
    initializeNavLinks();
    
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
    const addVehicleForm = document.getElementById('car-form');
    if (addVehicleForm) {
        addVehicleForm.addEventListener('submit', handleAddCar);
    }
});

// ===== UPDATE STATS =====
function updateStats() {
    const available = fleet.filter(car => car.status === 'available').length;
    const rented = fleet.filter(car => car.status === 'rented').length;
    const maintenance = fleet.filter(car => car.status === 'maintenance').length;
    const utilization = fleet.length > 0 ? Math.round((rented / fleet.length) * 100) : 0;
    
    // Calculate today's revenue (simplified)
    const todayRevenue = rentals
        .filter(r => r.status === 'active')
        .reduce((sum, r) => {
            const days = Math.ceil((r.returnDate - r.pickupDate) / (1000 * 60 * 60 * 24));
            const car = fleet.find(c => c.id === r.carId);
            return sum + (car ? car.rate * days : 0);
        }, 0);
    
    const analytics = getAnalytics();
    
    document.getElementById('available-count').textContent = available;
    document.getElementById('rented-count').textContent = rented;
    document.getElementById('maintenance-count').textContent = maintenance;
    document.getElementById('revenue-count').textContent = `$${todayRevenue}`;
    document.getElementById('utilization-count').textContent = `${utilization}%`;
    
    const todayBookingsEl = document.getElementById('today-bookings');
    if (todayBookingsEl) {
        todayBookingsEl.textContent = analytics.todayBookings;
    }
    
    // Update premium stats cards if they exist
    const monthBookingsEl = document.getElementById('month-bookings');
    if (monthBookingsEl) {
        monthBookingsEl.textContent = analytics.monthBookings;
    }
    
    const monthRevenueEl = document.getElementById('month-revenue');
    if (monthRevenueEl) {
        monthRevenueEl.textContent = `$${analytics.monthRevenue}`;
    }
    
    const completedRentalsEl = document.getElementById('completed-rentals');
    if (completedRentalsEl) {
        completedRentalsEl.textContent = analytics.completedRentals;
    }
    
    const avgRentalEl = document.getElementById('avg-rental-days');
    if (avgRentalEl) {
        avgRentalEl.textContent = analytics.averageRentalDays;
    }
}

function hasMeaningfulValue(value) {
    if (value === null || value === undefined) return false;
    const text = String(value).trim().toLowerCase();
    return text !== '' && text !== 'n/a' && text !== 'na' && text !== 'unknown' && text !== '-';
}

// ===== RENDER FLEET =====
function renderFleet(filter = 'all') {
    const grid = document.getElementById('fleet-grid');
    const filtered = filter === 'all' ? fleet : fleet.filter(car => car.status === filter);
    
    grid.innerHTML = filtered.map(car => {
        const makeModel = [car.make, car.model].filter(hasMeaningfulValue).join(' ');
        const statusText = hasMeaningfulValue(car.status) ? car.status : 'available';
        const primaryName = hasMeaningfulValue(car.name) ? car.name : makeModel || `Vehicle ${car.id}`;
        const carModelText = hasMeaningfulValue(makeModel) ? makeModel : (hasMeaningfulValue(car.model) ? car.model : 'Vehicle');

        const topDetails = [];
        const plateValue = hasMeaningfulValue(car.license) ? car.license : car.rego;
        if (hasMeaningfulValue(plateValue)) {
            topDetails.push(`🚗 ${plateValue}`);
        }
        if (hasMeaningfulValue(car.color)) {
            topDetails.push(`🎨 ${car.color}`);
        }
        if (Number.isFinite(Number(car.rate)) && Number(car.rate) > 0) {
            topDetails.push(`💰 $${Number(car.rate).toFixed(2)}`);
        }

        const secondaryDetails = [];
        if (Number.isFinite(Number(car.mileage)) && Number(car.mileage) > 0) {
            secondaryDetails.push(`📊 ${Number(car.mileage).toLocaleString()} km`);
        }
        if (hasMeaningfulValue(car.fuel) && String(car.fuel).toLowerCase() !== 'full') {
            secondaryDetails.push(`⛽ ${car.fuel}`);
        }

        return `
        <div class="fleet-card" data-id="${car.id}">
            <div class="car-header">
                <div>
                    <div class="car-name">${primaryName}</div>
                    <div class="car-model">${carModelText}</div>
                </div>
                <span class="status-badge status-${statusText}">
                    ${statusText.charAt(0).toUpperCase() + statusText.slice(1)}
                </span>
            </div>
            <div class="car-details">
                ${topDetails.map(detail => `<span>${detail}</span>`).join('')}
            </div>
            ${secondaryDetails.length ? `<div class="car-details">${secondaryDetails.map(detail => `<span>${detail}</span>`).join('')}</div>` : ''}
            <div class="car-actions">
                <button class="btn-small btn-qr" onclick="generateCarQR(${car.id})">
                    📱 Generate QR
                </button>
                <button class="btn-small btn-edit" onclick="editCar(${car.id})">
                    ✏️ Edit
                </button>
            </div>
        </div>
    `;
    }).join('');
}

function filterFleet(filter) {
    renderFleet(filter);
}

// ===== RENDER RENTALS =====
function renderRentals() {
    const list = document.getElementById('rentals-list');
    const activeRentals = rentals.filter(r => r.status === 'active');
    document.getElementById('active-rental-count').textContent = activeRentals.length;
    
    if (activeRentals.length === 0) {
        list.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No active rentals</p>';
        return;
    }
    
    list.innerHTML = activeRentals.map(rental => {
        const now = new Date();
        const timeUntilReturn = rental.returnDate - now;
        const hoursUntil = Math.floor(timeUntilReturn / (1000 * 60 * 60));
        const isOverdue = timeUntilReturn < 0;
        const customerName = hasMeaningfulValue(rental.customer) ? rental.customer : 'Customer';
        const carName = hasMeaningfulValue(rental.car) ? rental.car : 'Assigned Vehicle';
        const showPhone = hasMeaningfulValue(rental.phone);
        const pendingText = rental.importMeta?.pending;
        const unpaidText = rental.importMeta?.unpaidTotal;

        const rentalNotes = [];
        if (hasMeaningfulValue(pendingText) && String(pendingText).toLowerCase() !== 'clear') {
            rentalNotes.push(`⏳ ${pendingText}`);
        }
        if (hasMeaningfulValue(unpaidText) && String(unpaidText).trim() !== '$-' && String(unpaidText).trim() !== '$0.00') {
            rentalNotes.push(`💳 Unpaid ${unpaidText}`);
        }
        
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
                    <h4>${customerName} - ${carName}</h4>
                    ${showPhone ? `<p>📞 ${rental.phone}</p>` : ''}
                    ${rentalNotes.length ? `<p>${rentalNotes.join(' • ')}</p>` : ''}
                </div>
                <div class="rental-meta">
                    <div class="due-time">
                        <strong>Return Time</strong>
                        ${dueText}
                    </div>
                    <button class="btn-small btn-primary" onclick="showRentalDetails(${rental.id})">
                        View Details
                    </button>
                    <button class="btn-small btn-edit" onclick="completeRental(${rental.id})">
                        ✅ Complete
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

// ===== RENDER SERVICE HISTORY =====
function renderServiceHistory() {
    const historyList = document.getElementById('service-history-list');
    const pickups = JSON.parse(localStorage.getItem('veera-rentals-pickups') || '[]').slice(-5);
    const dropoffs = JSON.parse(localStorage.getItem('veera-rentals-dropoffs') || '[]').slice(-5);
    const swaps = JSON.parse(localStorage.getItem('veera-rentals-swaps') || '[]').slice(-5);
    
    const allServices = [
        ...pickups.map(p => ({ ...p, type: 'Pickup' })),
        ...dropoffs.map(d => ({ ...d, type: 'Drop-off' })),
        ...swaps.map(s => ({ ...s, type: 'Swap' }))
    ].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp)).slice(0, 8);
    
    if (allServices.length === 0) {
        historyList.innerHTML = '<div style="padding: 2rem; text-align: center; color: #999;"><p>No service records yet</p></div>';
        return;
    }
    
    historyList.innerHTML = allServices.map(service => {
        const date = new Date(service.timestamp);
        const typeIcon = service.type === 'Pickup' ? '📤' : service.type === 'Drop-off' ? '📥' : '🔄';
        const typeColor = service.type === 'Pickup' ? '#3b82f6' : service.type === 'Drop-off' ? '#10b981' : '#f59e0b';
        
        return `
            <div style="background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 1rem; display: flex; justify-content: space-between; align-items: center;">
                <div style="flex: 1;">
                    <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.35rem;">
                        <span style="font-size: 1.5rem;">${typeIcon}</span>
                        <div>
                            <strong style="color: #1f2937;">${service.type} - ${service.customerName || 'Customer'}</strong>
                            <div style="font-size: 0.85rem; color: #6b7280;">${service.vehicle ? service.vehicle.name || service.vehicle.rego : 'Vehicle N/A'}</div>
                        </div>
                    </div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 0.9rem; color: #6b7280; margin-bottom: 0.25rem;">${date.toLocaleDateString()} ${date.toLocaleTimeString()}</div>
                    <div style="font-size: 0.85rem; background: ${typeColor}15; color: ${typeColor}; padding: 0.25rem 0.75rem; border-radius: 20px; font-weight: 500;">Ref: ${service.serviceRef || 'N/A'}</div>
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
    showModal('car-modal');
}

// ===== ADD CAR FUNCTIONS =====
function handleAddCar(e) {
    if (e) e.preventDefault();
    
    const carName = document.getElementById('car-name')?.value?.trim() || '';
    const carModel = document.getElementById('car-model')?.value?.trim() || '';
    const rate = parseFloat(document.getElementById('car-rate')?.value || '0');
    const mileage = parseInt(document.getElementById('car-mileage')?.value || '0', 10) || 0;
    const fuel = document.getElementById('car-fuel')?.value || 'Full';
    const license = document.getElementById('car-license')?.value?.trim() || '';
    const color = document.getElementById('car-color')?.value || 'Unknown';
    const vin = document.getElementById('car-vin')?.value || 'N/A';
    
    if (!carName || !carModel || !license || !Number.isFinite(rate) || rate <= 0) {
        showToast('Please fill all required fields with a valid daily rate', 'warning');
        return;
    }
    
    const newCar = {
        id: Math.max(...fleet.map(c => c.id), 0) + 1,
        name: carName,
        model: carModel,
        status: 'available',
        rate: rate,
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
    
    closeModal('car-modal');
    if (document.getElementById('car-form')) {
        document.getElementById('car-form').reset();
    }
    
    showToast(`Car added successfully (ID: ${newCar.id})`, 'success');
}

function showInspection() {
    showToast('Inspection tool opens scanner.html', 'info');
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
    link.download = `rental-export-${new Date().toISOString().split('T')[0]}.json`;
    link.click();
    URL.revokeObjectURL(url);
    
    showToast('Data exported successfully', 'success');
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
${[...fleet].sort((a, b) => b.rate - a.rate).slice(0, 3).map(c => 
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
        link.download = `rental-report-${today.toISOString().split('T')[0]}.txt`;
        link.click();
        URL.revokeObjectURL(url);
    }
}

// ===== QR CODE GENERATION =====
function generateCarQR(carId) {
    const car = fleet.find(c => c.id === carId);
    if (!car) return;
    
    const rental = rentals.find(r => r.carId === carId && r.status === 'active');
    
    const scannerUrl = new URL('scanner.html', window.location.href).toString();

    const qrData = {
        type: 'car_access',
        carId: car.id,
        carName: car.name,
        license: car.license,
        status: car.status,
        rentalId: rental?.id || null,
        customer: rental?.customer || 'Available for Booking',
        timestamp: new Date().toISOString(),
        scannerUrl
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
        showToast('Failed to generate QR code. Please try again.', 'error');
    }
}

function generateQR() {
    if (fleet.length === 0) {
        showToast('No cars available. Please add a car first.', 'warning');
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
            `<option value="${car.id}">${car.name} - ${car.model} ($${car.rate}/day)</option>`
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
        showToast('Please select a car', 'warning');
        return;
    }

    if (Number.isNaN(pickupDate.getTime()) || Number.isNaN(returnDate.getTime())) {
        showToast('Please enter valid pickup and return dates', 'warning');
        return;
    }

    if (returnDate <= pickupDate) {
        showToast('Return date must be after pickup date', 'warning');
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
    renderServiceHistory();
    
    // Close modal and reset form
    closeModal('booking-modal');
    document.getElementById('booking-form').reset();
    initializeBookingDateInputs();
    
    // Show booking summary
    const days = Math.ceil((returnDate - pickupDate) / (1000 * 60 * 60 * 24));
    const total = car.rate * days;
    const summaryMessage = `✅ Booking Created!\n\nCustomer: ${customerName}\nVehicle: ${car.name}\nDays: ${days}\nTotal: $${total}\n\nQR code generated. Ready for pickup!`;
    
    setTimeout(() => {
        showToast(`✅ ${customerName}'s booking confirmed!`, 'success');
        alert(summaryMessage);
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
        showToast(`Updated ${car.name} to ${newStatus}`, 'success');
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

function completeRental(rentalId) {
    const rental = rentals.find(r => r.id === rentalId);
    if (!rental || rental.status !== 'active') {
        showToast('Rental is not active', 'warning');
        return;
    }

    const shouldComplete = confirm(`Complete rental for ${rental.customer}?`);
    if (!shouldComplete) return;

    rental.status = 'completed';
    rental.completedAt = new Date();

    const car = fleet.find(c => c.id === rental.carId);
    if (car) {
        car.status = 'available';
    }

    saveData();
    updateStats();
    renderFleet();
    renderRentals();
    populateCarSelect();

    showToast(`Rental #${rental.id} marked as completed`, 'success');
}

// ===== TOAST NOTIFICATIONS =====
function showToast(message, type = 'info', duration = 3000) {
    const existingToast = document.getElementById('toast-container');
    if (existingToast) existingToast.remove();
    
    const toastContainer = document.createElement('div');
    toastContainer.id = 'toast-container';
    toastContainer.style.cssText = `
        position: fixed;
        bottom: 2rem;
        right: 2rem;
        background: ${type === 'success' ? '#10b981' : type === 'error' ? '#ef4444' : type === 'warning' ? '#f59e0b' : '#3b82f6'};
        color: white;
        padding: 1rem 1.5rem;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        z-index: 9999;
        animation: slideIn 0.3s ease-out;
        font-weight: 500;
        max-width: 300px;
    `;
    toastContainer.textContent = message;
    document.body.appendChild(toastContainer);
    
    setTimeout(() => {
        toastContainer.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => toastContainer.remove(), 300);
    }, duration);
}

// Add animation styles
if (!document.getElementById('toast-styles')) {
    const style = document.createElement('style');
    style.id = 'toast-styles';
    style.textContent = `
        @keyframes slideIn {
            from { transform: translateX(400px); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }
        @keyframes slideOut {
            from { transform: translateX(0); opacity: 1; }
            to { transform: translateX(400px); opacity: 0; }
        }
    `;
    document.head.appendChild(style);
}

// ===== ADVANCED ANALYTICS =====
function getAnalytics() {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    const todayRentals = rentals.filter(r => {
        const rentalDate = new Date(r.pickupDate);
        const rentalDay = new Date(rentalDate.getFullYear(), rentalDate.getMonth(), rentalDate.getDate());
        return rentalDay.getTime() === today.getTime();
    });
    
    const thisMonthRentals = rentals.filter(r => {
        const rentalDate = new Date(r.pickupDate);
        return rentalDate >= thisMonth;
    });
    
    const completedRentals = rentals.filter(r => r.status === 'completed');
    const averageRentalDays = completedRentals.length > 0 
        ? completedRentals.reduce((sum, r) => {
            const days = Math.ceil((new Date(r.returnDate) - new Date(r.pickupDate)) / (1000 * 60 * 60 * 24));
            return sum + days;
          }, 0) / completedRentals.length
        : 0;
    
    const totalRevenue = todayRentals.reduce((sum, r) => {
        const car = fleet.find(c => c.id === r.carId);
        const days = Math.ceil((new Date(r.returnDate) - new Date(r.pickupDate)) / (1000 * 60 * 60 * 24));
        return sum + (car ? car.rate * days : 0);
    }, 0);
    
    return {
        todayBookings: todayRentals.length,
        monthBookings: thisMonthRentals.length,
        completedRentals: completedRentals.length,
        averageRentalDays: averageRentalDays.toFixed(1),
        totalRevenue: totalRevenue.toFixed(2),
        monthRevenue: thisMonthRentals.reduce((sum, r) => {
            const car = fleet.find(c => c.id === r.carId);
            const days = Math.ceil((new Date(r.returnDate) - new Date(r.pickupDate)) / (1000 * 60 * 60 * 24));
            return sum + (car ? car.rate * days : 0);
        }, 0).toFixed(2)
    };
}

function showDailyReport() {
    const analytics = getAnalytics();
    const revenue = parseFloat(analytics.totalRevenue);
    const available = fleet.filter(c => c.status === 'available').length;
    const rented = fleet.filter(c => c.status === 'rented').length;
    const utilization = ((rented / fleet.length) * 100).toFixed(1);
    
    const reportHTML = `
        📊 DAILY REPORT - ${new Date().toLocaleDateString()}
        
        BOOKINGS:
        Today's Bookings: ${analytics.todayBookings}
        This Month: ${analytics.monthBookings}
        
        FLEET STATUS:
        Available: ${available}/${fleet.length}
        Currently Rented: ${rented}
        Utilization: ${utilization}%
        
        REVENUE:
        Today: $${revenue}
        This Month: $${analytics.monthRevenue}
        
        STATISTICS:
        Completed Rentals: ${analytics.completedRentals}
        Average Rental Days: ${analytics.averageRentalDays}
    `;
    
    alert(reportHTML);
    
    // Option to download CSV
    const csvContent = `Date,Metric,Value\n${new Date().toLocaleDateString()},Today Bookings,${analytics.todayBookings}\n${new Date().toLocaleDateString()},Daily Revenue,$${revenue}\n${new Date().toLocaleDateString()},Fleet Utilization,${utilization}%`;
    
    const downloadLink = document.createElement('a');
    downloadLink.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
    downloadLink.setAttribute('download', `report-${new Date().toISOString().split('T')[0]}.csv`);
    downloadLink.click();
}

function exportData() {
    const data = {
        fleet: fleet,
        rentals: rentals,
        exportDate: new Date().toISOString(),
        analytics: getAnalytics()
    };
    
    const csv = 'Rental,Customer,Car,Pickup,Return,Status,Days,Amount\n' + rentals.map(r => {
        const car = fleet.find(c => c.id === r.carId);
        const days = Math.ceil((new Date(r.returnDate) - new Date(r.pickupDate)) / (1000 * 60 * 60 * 24));
        const amount = car ? car.rate * days : 0;
        return `${r.id},"${r.customer}","${r.car}","${new Date(r.pickupDate).toLocaleDateString()}","${new Date(r.returnDate).toLocaleDateString()}","${r.status}",${days},$${amount}`;
    }).join('\n');
    
    const link = document.createElement('a');
    link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
    link.setAttribute('download', `rentals-${new Date().toISOString().split('T')[0]}.csv`);
    link.click();
    
    showToast('Data exported successfully!', 'success');
}

// ===== AUTO REFRESH =====
// Update time-sensitive displays every minute
setInterval(() => {
    renderRentals();
}, 60000);
