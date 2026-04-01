// Enhanced Admin Panel JavaScript for Veera Rentals

const PRIMARY_INVOICES_KEY = 'rentals-invoices-data';
const LEGACY_INVOICES_KEY = 'veera-rentals-invoices';

function readInvoices() {
    const primaryRaw = localStorage.getItem(PRIMARY_INVOICES_KEY);
    const legacyRaw = localStorage.getItem(LEGACY_INVOICES_KEY);

    try {
        if (primaryRaw) {
            const parsed = JSON.parse(primaryRaw);
            if (Array.isArray(parsed)) return parsed;
        }

        if (legacyRaw) {
            const parsedLegacy = JSON.parse(legacyRaw);
            if (Array.isArray(parsedLegacy)) {
                localStorage.setItem(PRIMARY_INVOICES_KEY, JSON.stringify(parsedLegacy));
                return parsedLegacy;
            }
        }
    } catch (error) {
        console.warn('Invoice storage parse failed:', error);
    }

    return [];
}

function writeInvoices(invoices) {
    localStorage.setItem(PRIMARY_INVOICES_KEY, JSON.stringify(invoices));
    localStorage.setItem(LEGACY_INVOICES_KEY, JSON.stringify(invoices));
}

function parseStorageArray(key) {
    try {
        const raw = localStorage.getItem(key);
        if (!raw) return [];
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
        console.warn(`Storage parse failed for ${key}:`, error);
        return [];
    }
}

// Tab Navigation
function showTab(tabName) {
    // Hide all sections
    document.querySelectorAll('.tab-content').forEach(section => {
        section.style.display = 'none';
    });
    
    // Remove active class from all nav links
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    // Show selected section
    const selectedSection = document.getElementById(`${tabName}-section`);
    if (selectedSection) {
        selectedSection.style.display = 'block';
    }
    
    // Add active class to clicked nav link
    const activeLink = document.querySelector(`[data-tab="${tabName}"]`);
    if (activeLink) {
        activeLink.classList.add('active');
    }
    
    // Load data for specific tabs
    if (tabName === 'bookings') {
        renderAllBookings();
    } else if (tabName === 'inventory') {
        renderInventory();
    } else if (tabName === 'invoices') {
        renderInvoices();
    } else if (tabName === 'reports') {
        renderReports();
    }
}

// Render All Bookings
function renderAllBookings() {
    const pickups = parseStorageArray('veera-rentals-pickups');
    const dropoffs = parseStorageArray('veera-rentals-dropoffs');
    const swaps = parseStorageArray('veera-rentals-swaps');
    
    const bookingsGrid = document.getElementById('bookings-grid');
    
    const allBookings = [
        ...pickups.map(b => ({ ...b, type: 'Pickup' })),
        ...dropoffs.map(b => ({ ...b, type: 'Drop-off' })),
        ...swaps.map(b => ({ ...b, type: 'Swap' }))
    ].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    if (allBookings.length === 0) {
        bookingsGrid.innerHTML = '<p class="empty-state">No bookings found. Start by adding vehicles and processing pickups!</p>';
        return;
    }
    
    bookingsGrid.innerHTML = allBookings.map(booking => `
        <div class="booking-card ${booking.type.toLowerCase()}">
            <div class="booking-header">
                <span class="booking-type-badge">${booking.type}</span>
                <span class="booking-ref">${booking.serviceRef}</span>
            </div>
            <div class="booking-details">
                <p><strong>Customer:</strong> ${booking.customerName}</p>
                <p><strong>Phone:</strong> ${booking.customerPhone}</p>
                <p><strong>Vehicle:</strong> ${booking.vehicle.make} ${booking.vehicle.model} (${booking.vehicle.rego})</p>
                <p><strong>Mileage:</strong> ${booking.mileage} km</p>
                <p><strong>Fuel:</strong> ${booking.fuel}</p>
                <p><strong>Date:</strong> ${new Date(booking.timestamp).toLocaleString()}</p>
                ${booking.location ? `<p><strong>Location:</strong> <a href="https://www.google.com/maps?q=${booking.location.lat},${booking.location.lng}" target="_blank">${booking.location.lat.toFixed(6)}, ${booking.location.lng.toFixed(6)}</a></p>` : ''}
                ${booking.notes ? `<p><strong>Notes:</strong> ${booking.notes}</p>` : ''}
            </div>
        </div>
    `).join('');
}

// Render Inventory (Fleet)
function renderInventory() {
    const fleet = parseStorageArray('fleet-data');
    const inventoryGrid = document.getElementById('inventory-grid');
    
    if (fleet.length === 0) {
        inventoryGrid.innerHTML = '<p class="empty-state">No vehicles in fleet. Add vehicles to get started!</p>';
        return;
    }
    
    const available = fleet.filter(v => v.status === 'available');
    const rented = fleet.filter(v => v.status === 'rented');
    const maintenance = fleet.filter(v => v.status === 'maintenance');
    
    inventoryGrid.innerHTML = `
        <div class="inventory-stats">
            <div class="inv-stat available">
                <h3>${available.length}</h3>
                <p>Available</p>
            </div>
            <div class="inv-stat rented">
                <h3>${rented.length}</h3>
                <p>Rented</p>
            </div>
            <div class="inv-stat maintenance">
                <h3>${maintenance.length}</h3>
                <p>Maintenance</p>
            </div>
        </div>
        <div class="inventory-list">
            ${fleet.map(vehicle => `
                <div class="vehicle-card status-${vehicle.status}">
                    <div class="vehicle-header">
                        <h3>${vehicle.make} ${vehicle.model}</h3>
                        <span class="status-badge ${vehicle.status}">${vehicle.status}</span>
                    </div>
                    <div class="vehicle-details">
                        <p><strong>Rego:</strong> ${vehicle.rego}</p>
                        <p><strong>Color:</strong> ${vehicle.color || 'N/A'}</p>
                        <p><strong>Mileage:</strong> ${vehicle.mileage || 0} km</p>
                        <p><strong>Rate:</strong> $${vehicle.rate}/day</p>
                        <p><strong>VIN:</strong> ${vehicle.vin || 'N/A'}</p>
                    </div>
                    <button class="btn btn-small" onclick="changeVehicleStatus('${vehicle.id}')">Change Status</button>
                </div>
            `).join('')}
        </div>
    `;
}

// Render Invoices
function renderInvoices() {
    const invoices = readInvoices();
    const invoicesGrid = document.getElementById('invoices-grid');
    
    const totalRevenue = invoices.reduce((sum, inv) => sum + parseFloat(inv.amount || 0), 0);
    const paidInvoices = invoices.filter(inv => inv.status === 'paid');
    const unpaidInvoices = invoices.filter(inv => inv.status === 'unpaid');
    
    invoicesGrid.innerHTML = `
        <div class="invoice-header">
            <button class="btn btn-primary" onclick="showAddInvoiceModal()">+ Add Invoice</button>
            <div class="invoice-stats">
                <div class="stat-box">
                    <h4>$${totalRevenue.toFixed(2)}</h4>
                    <p>Total Revenue</p>
                </div>
                <div class="stat-box">
                    <h4>${paidInvoices.length}</h4>
                    <p>Paid</p>
                </div>
                <div class="stat-box">
                    <h4>${unpaidInvoices.length}</h4>
                    <p>Unpaid</p>
                </div>
            </div>
        </div>
        <div class="invoices-list">
            ${invoices.length === 0 ? '<p class="empty-state">No invoices yet. Create your first invoice!</p>' : ''}
            ${invoices.sort((a, b) => new Date(b.date) - new Date(a.date)).map(invoice => `
                <div class="invoice-card ${invoice.status}">
                    <div class="invoice-row">
                        <div class="invoice-info">
                            <h4>Invoice #${invoice.invoiceNumber}</h4>
                            <p>${invoice.customerName} - ${invoice.description}</p>
                            <small>${new Date(invoice.date).toLocaleDateString()}</small>
                        </div>
                        <div class="invoice-amount">
                            <h3>$${invoice.amount}</h3>
                            <span class="status-badge ${invoice.status}">${invoice.status}</span>
                        </div>
                    </div>
                    <div class="invoice-actions">
                        <button class="btn btn-small" onclick="toggleInvoiceStatus('${invoice.invoiceNumber}')">
                            ${invoice.status === 'paid' ? 'Mark Unpaid' : 'Mark Paid'}
                        </button>
                        <button class="btn btn-small btn-danger" onclick="deleteInvoice('${invoice.invoiceNumber}')">Delete</button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

// Render Reports
function renderReports() {
    const pickups = parseStorageArray('veera-rentals-pickups');
    const dropoffs = parseStorageArray('veera-rentals-dropoffs');
    const invoices = readInvoices();
    const fleet = parseStorageArray('fleet-data');
    
    const totalRevenue = invoices.reduce((sum, inv) => sum + parseFloat(inv.amount || 0), 0);
    const todayRevenue = invoices.filter(inv => {
        const invDate = new Date(inv.date).toDateString();
        return invDate === new Date().toDateString();
    }).reduce((sum, inv) => sum + parseFloat(inv.amount || 0), 0);
    
    const utilization = fleet.length > 0 ? ((fleet.filter(v => v.status === 'rented').length / fleet.length) * 100).toFixed(1) : 0;
    
    document.getElementById('reports-content').innerHTML = `
        <div class="reports-grid">
            <div class="report-card">
                <h3>Revenue Summary</h3>
                <div class="report-stats">
                    <p><strong>Total Revenue:</strong> $${totalRevenue.toFixed(2)}</p>
                    <p><strong>Today's Revenue:</strong> $${todayRevenue.toFixed(2)}</p>
                    <p><strong>Total Invoices:</strong> ${invoices.length}</p>
                </div>
            </div>
            <div class="report-card">
                <h3>Fleet Statistics</h3>
                <div class="report-stats">
                    <p><strong>Total Vehicles:</strong> ${fleet.length}</p>
                    <p><strong>Available:</strong> ${fleet.filter(v => v.status === 'available').length}</p>
                    <p><strong>Rented:</strong> ${fleet.filter(v => v.status === 'rented').length}</p>
                    <p><strong>Utilization:</strong> ${utilization}%</p>
                </div>
            </div>
            <div class="report-card">
                <h3>Service Activity</h3>
                <div class="report-stats">
                    <p><strong>Total Pickups:</strong> ${pickups.length}</p>
                    <p><strong>Total Drop-offs:</strong> ${dropoffs.length}</p>
                    <p><strong>Active Rentals:</strong> ${pickups.length - dropoffs.length}</p>
                </div>
            </div>
        </div>
        <div class="export-section">
            <button class="btn btn-primary" onclick="exportAllData()">Export All Data</button>
            <button class="btn btn-secondary" onclick="printReport()">Print Report</button>
        </div>
    `;
}

// Add Invoice Modal
function showAddInvoiceModal() {
    const modal = document.getElementById('invoice-modal');
    if (!modal) {
        const modalHTML = `
            <div id="invoice-modal" class="modal active">
                <div class="modal-content">
                    <div class="modal-header">
                        <h2>Add New Invoice</h2>
                        <button class="close-btn" onclick="closeInvoiceModal()">×</button>
                    </div>
                    <form id="invoice-form">
                        <div class="form-group">
                            <label>Invoice Number</label>
                            <input type="text" id="invoice-number" value="INV-${Date.now()}" required>
                        </div>
                        <div class="form-group">
                            <label>Customer Name</label>
                            <input type="text" id="invoice-customer" required>
                        </div>
                        <div class="form-group">
                            <label>Description</label>
                            <input type="text" id="invoice-description" placeholder="Rental payment, Extra charges, etc." required>
                        </div>
                        <div class="form-group">
                            <label>Amount ($)</label>
                            <input type="number" id="invoice-amount" step="0.01" required>
                        </div>
                        <div class="form-group">
                            <label>Status</label>
                            <select id="invoice-status">
                                <option value="unpaid">Unpaid</option>
                                <option value="paid">Paid</option>
                            </select>
                        </div>
                        <button type="submit" class="btn btn-primary">Save Invoice</button>
                    </form>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHTML);
        
        document.getElementById('invoice-form').addEventListener('submit', saveInvoice);
    } else {
        modal.classList.add('active');
    }
}

function closeInvoiceModal() {
    document.getElementById('invoice-modal').classList.remove('active');
}

function saveInvoice(e) {
    e.preventDefault();
    
    const invoice = {
        invoiceNumber: document.getElementById('invoice-number').value,
        customerName: document.getElementById('invoice-customer').value,
        description: document.getElementById('invoice-description').value,
        amount: document.getElementById('invoice-amount').value,
        status: document.getElementById('invoice-status').value,
        date: new Date().toISOString()
    };
    
    const invoices = readInvoices();
    invoices.push(invoice);
    writeInvoices(invoices);
    
    closeInvoiceModal();
    renderInvoices();
    alert('Invoice added successfully!');
}

function toggleInvoiceStatus(invoiceNumber) {
    const invoices = readInvoices();
    const invoice = invoices.find(inv => inv.invoiceNumber === invoiceNumber);
    
    if (invoice) {
        invoice.status = invoice.status === 'paid' ? 'unpaid' : 'paid';
        writeInvoices(invoices);
        renderInvoices();
    }
}

function deleteInvoice(invoiceNumber) {
    if (confirm('Are you sure you want to delete this invoice?')) {
        let invoices = readInvoices();
        invoices = invoices.filter(inv => inv.invoiceNumber !== invoiceNumber);
        writeInvoices(invoices);
        renderInvoices();
    }
}

function changeVehicleStatus(vehicleId) {
    const fleet = parseStorageArray('fleet-data');
    const vehicle = fleet.find(v => v.id === vehicleId);
    
    if (vehicle) {
        const statuses = ['available', 'rented', 'maintenance'];
        const currentIndex = statuses.indexOf(vehicle.status);
        const nextIndex = (currentIndex + 1) % statuses.length;
        vehicle.status = statuses[nextIndex];
        
        localStorage.setItem('fleet-data', JSON.stringify(fleet));
        renderInventory();
    }
}

function exportAllData() {
    const data = {
        fleet: parseStorageArray('fleet-data'),
        pickups: parseStorageArray('veera-rentals-pickups'),
        dropoffs: parseStorageArray('veera-rentals-dropoffs'),
        swaps: parseStorageArray('veera-rentals-swaps'),
        invoices: readInvoices()
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `veera-rentals-export-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
}

function printReport() {
    window.print();
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    // Set up tab navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const tab = link.getAttribute('data-tab');
            showTab(tab);
        });
    });
    
    // Show dashboard by default
    showTab('dashboard');
});
