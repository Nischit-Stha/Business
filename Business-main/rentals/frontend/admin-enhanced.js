// Enhanced Admin Panel JavaScript for Veera Rentals (Supabase-only)

function getSupabaseClient() {
    if (typeof window.getVeeraSupabaseClient === 'function') {
        return window.getVeeraSupabaseClient();
    }
    return null;
}

function sanitizeText(value, fallback = 'N/A') {
    if (value === null || value === undefined || value === '') return fallback;
    return String(value);
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function isHttpUrl(value) {
    return /^https?:\/\//i.test(String(value || '').trim());
}

function extractServicePayloadsFromNotes(notes) {
    const text = String(notes || '').trim();
    if (!text) return [];

    const payloads = [];

    const parseJsonBlock = (jsonText) => {
        try {
            const parsed = JSON.parse(jsonText);
            if (Array.isArray(parsed)) {
                parsed.forEach(item => {
                    if (item && typeof item === 'object') {
                        payloads.push(item);
                    }
                });
                return;
            }

            if (parsed && typeof parsed === 'object') {
                payloads.push(parsed);
            }
        } catch {
            // Ignore malformed JSON payloads in notes.
        }
    };

    text
        .split('\n')
        .map(line => String(line || '').trim())
        .filter(Boolean)
        .forEach(line => {
            if (line.includes('SCANNER_FORM::')) {
                parseJsonBlock(line.slice(line.indexOf('SCANNER_FORM::') + 'SCANNER_FORM::'.length).trim());
                return;
            }

            if (line.includes('SERVICE_EVENT::')) {
                parseJsonBlock(line.slice(line.indexOf('SERVICE_EVENT::') + 'SERVICE_EVENT::'.length).trim());
                return;
            }

            if (line.startsWith('{') || line.startsWith('[')) {
                parseJsonBlock(line);
            }
        });

    return payloads;
}

function extractPhotoUrlsFromNotes(notes) {
    const payloads = extractServicePayloadsFromNotes(notes);
    if (!payloads.length) return [];

    const urls = new Set();
    const addUrls = (maybeUrls) => {
        if (!Array.isArray(maybeUrls)) return;
        maybeUrls
            .map(item => String(item || '').trim())
            .filter(isHttpUrl)
            .forEach(url => urls.add(url));
    };

    payloads.forEach(payload => addUrls(payload.photoUrls));

    return Array.from(urls);
}

function renderLocationFromNotes(notes) {
    const payloads = extractServicePayloadsFromNotes(notes);
    if (!payloads.length) return '';

    const latestWithLocation = [...payloads]
        .reverse()
        .find(payload => payload && payload.location && payload.location.lat && payload.location.lng);

    if (!latestWithLocation) return '';

    const lat = Number(latestWithLocation.location.lat);
    const lng = Number(latestWithLocation.location.lng);

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return '';

    const latText = lat.toFixed(6);
    const lngText = lng.toFixed(6);
    const mapsUrl = `https://maps.google.com/?q=${encodeURIComponent(`${latText},${lngText}`)}`;

    return `<p><strong>Location:</strong> ${latText}, ${lngText} <a href="${escapeHtml(mapsUrl)}" target="_blank" rel="noopener noreferrer">Open Map</a></p>`;
}

function renderPhotoLinksFromNotes(notes) {
    const photoUrls = extractPhotoUrlsFromNotes(notes);
    if (!photoUrls.length) return '';

    const links = photoUrls
        .map((url, index) => `<a href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer">Photo ${index + 1}</a>`)
        .join(' | ');

    return `<p><strong>Photos:</strong> ${links}</p>`;
}

function toCurrency(value) {
    return `$${Number(value || 0).toFixed(2)}`;
}

async function fetchBookings() {
    const client = getSupabaseClient();
    if (!client) return [];

    try {
        const { data, error } = await client
            .from('booking_requests')
            .select('*')
            .order('created_at', { ascending: false });

        if (error || !Array.isArray(data)) {
            if (error) console.warn('Admin bookings load failed:', error.message || error);
            return [];
        }

        return data;
    } catch (error) {
        console.warn('Admin bookings load exception:', error);
        return [];
    }
}

async function fetchFleet() {
    const client = getSupabaseClient();
    if (!client) return [];

    try {
        const { data, error } = await client
            .from('vehicles')
            .select('id,name,make,model,plate,status,rate_day,mileage,color')
            .order('id', { ascending: true });

        if (error || !Array.isArray(data)) {
            if (error) console.warn('Admin fleet load failed:', error.message || error);
            return [];
        }

        return data;
    } catch (error) {
        console.warn('Admin fleet load exception:', error);
        return [];
    }
}

async function fetchInvoices() {
    const client = getSupabaseClient();
    if (!client) return [];

    try {
        const { data, error } = await client
            .from('invoices')
            .select('*')
            .order('created_at', { ascending: false });

        if (error || !Array.isArray(data)) {
            if (error) console.warn('Admin invoices load failed:', error.message || error);
            return [];
        }

        return data;
    } catch (error) {
        console.warn('Admin invoices load exception:', error);
        return [];
    }
}

// Tab Navigation
async function showTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(section => {
        section.style.display = 'none';
    });

    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });

    const selectedSection = document.getElementById(`${tabName}-section`);
    if (selectedSection) {
        selectedSection.style.display = 'block';
    }

    const activeLink = document.querySelector(`[data-tab="${tabName}"]`);
    if (activeLink) {
        activeLink.classList.add('active');
    }

    if (tabName === 'bookings') {
        await renderAllBookings();
    } else if (tabName === 'inventory') {
        await renderInventory();
    } else if (tabName === 'invoices') {
        await renderInvoices();
    } else if (tabName === 'reports') {
        await renderReports();
    }
}

// Render All Bookings
async function renderAllBookings() {
    const bookings = await fetchBookings();
    const bookingsGrid = document.getElementById('bookings-grid');

    if (!bookings.length) {
        bookingsGrid.innerHTML = '<p class="empty-state">No bookings found.</p>';
        return;
    }

    bookingsGrid.innerHTML = bookings.map(booking => {
        const createdAt = booking.created_at || new Date().toISOString();
        const vehicleText = sanitizeText(booking.car || booking.car_name, `Vehicle #${Number(booking.vehicle_id || 0) || ''}`);
        return `
            <div class="booking-card ${String(booking.status || '').toLowerCase()}">
                <div class="booking-header">
                    <span class="booking-type-badge">${sanitizeText(booking.status, 'pending')}</span>
                    <span class="booking-ref">#${Number(booking.id || 0)}</span>
                </div>
                <div class="booking-details">
                    <p><strong>Customer:</strong> ${sanitizeText(booking.customer)}</p>
                    <p><strong>Phone:</strong> ${sanitizeText(booking.phone)}</p>
                    <p><strong>Email:</strong> ${sanitizeText(booking.email)}</p>
                    <p><strong>Vehicle:</strong> ${vehicleText}</p>
                    <p><strong>Pickup:</strong> ${booking.pickup_at ? new Date(booking.pickup_at).toLocaleString() : 'N/A'}</p>
                    <p><strong>Return:</strong> ${booking.return_at ? new Date(booking.return_at).toLocaleString() : 'N/A'}</p>
                    <p><strong>Created:</strong> ${new Date(createdAt).toLocaleString()}</p>
                    ${renderLocationFromNotes(booking.notes)}
                    ${renderPhotoLinksFromNotes(booking.notes)}
                </div>
            </div>
        `;
    }).join('');
}

// Render Inventory (Fleet)
async function renderInventory() {
    const fleet = await fetchFleet();
    const inventoryGrid = document.getElementById('inventory-grid');

    if (!fleet.length) {
        inventoryGrid.innerHTML = '<p class="empty-state">No vehicles in fleet.</p>';
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
                        <h3>${sanitizeText(vehicle.name, `${sanitizeText(vehicle.make, '')} ${sanitizeText(vehicle.model, '')}`.trim() || 'Vehicle')}</h3>
                        <span class="status-badge ${vehicle.status}">${sanitizeText(vehicle.status, 'available')}</span>
                    </div>
                    <div class="vehicle-details">
                        <p><strong>Rego:</strong> ${sanitizeText(vehicle.plate)}</p>
                        <p><strong>Color:</strong> ${sanitizeText(vehicle.color)}</p>
                        <p><strong>Mileage:</strong> ${Number(vehicle.mileage || 0)} km</p>
                        <p><strong>Rate:</strong> ${toCurrency(vehicle.rate_day)}/day</p>
                    </div>
                    <button class="btn btn-small" onclick="changeVehicleStatus(${Number(vehicle.id)})">Change Status</button>
                </div>
            `).join('')}
        </div>
    `;
}

// Render Invoices
async function renderInvoices() {
    const invoices = await fetchInvoices();
    const invoicesGrid = document.getElementById('invoices-grid');

    const totalRevenue = invoices.reduce((sum, inv) => sum + Number(inv.total_amount || 0), 0);
    const paidInvoices = invoices.filter(inv => String(inv.status || '').toLowerCase() === 'paid');
    const unpaidInvoices = invoices.filter(inv => String(inv.status || '').toLowerCase() !== 'paid');

    invoicesGrid.innerHTML = `
        <div class="invoice-header">
            <button class="btn btn-primary" onclick="showAddInvoiceModal()">+ Add Invoice</button>
            <div class="invoice-stats">
                <div class="stat-box">
                    <h4>${toCurrency(totalRevenue)}</h4>
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
            ${invoices.length === 0 ? '<p class="empty-state">No invoices yet.</p>' : ''}
            ${invoices.map(invoice => `
                <div class="invoice-card ${String(invoice.status || '').toLowerCase()}">
                    <div class="invoice-row">
                        <div class="invoice-info">
                            <h4>Invoice #${sanitizeText(invoice.invoice_no || invoice.invoice_number || invoice.invoiceNumber)}</h4>
                            <p>${sanitizeText(invoice.customer)} - ${sanitizeText(invoice.notes, 'Rental invoice')}</p>
                            <small>${new Date(invoice.issue_date || invoice.created_at || Date.now()).toLocaleDateString()}</small>
                        </div>
                        <div class="invoice-amount">
                            <h3>${toCurrency(invoice.total_amount)}</h3>
                            <span class="status-badge ${String(invoice.status || '').toLowerCase()}">${sanitizeText(invoice.status, 'open')}</span>
                        </div>
                    </div>
                    <div class="invoice-actions">
                        <button class="btn btn-small" onclick="toggleInvoiceStatus('${sanitizeText(invoice.invoice_no || invoice.invoice_number || invoice.invoiceNumber, '').replace(/'/g, "\\'")}')">
                            ${String(invoice.status || '').toLowerCase() === 'paid' ? 'Mark Unpaid' : 'Mark Paid'}
                        </button>
                        <button class="btn btn-small btn-danger" onclick="deleteInvoice('${sanitizeText(invoice.invoice_no || invoice.invoice_number || invoice.invoiceNumber, '').replace(/'/g, "\\'")}')">Delete</button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

// Render Reports
async function renderReports() {
    const [bookings, invoices, fleet] = await Promise.all([fetchBookings(), fetchInvoices(), fetchFleet()]);

    const totalRevenue = invoices.reduce((sum, inv) => sum + Number(inv.total_amount || 0), 0);
    const todayRevenue = invoices.filter(inv => {
        const invDate = new Date(inv.issue_date || inv.created_at || 0).toDateString();
        return invDate === new Date().toDateString();
    }).reduce((sum, inv) => sum + Number(inv.total_amount || 0), 0);

    const utilization = fleet.length > 0
        ? ((fleet.filter(v => v.status === 'rented').length / fleet.length) * 100).toFixed(1)
        : 0;

    const activeBookings = bookings.filter(item => ['active', 'approved'].includes(String(item.status || '').toLowerCase()));

    document.getElementById('reports-content').innerHTML = `
        <div class="reports-grid">
            <div class="report-card">
                <h3>Revenue Summary</h3>
                <div class="report-stats">
                    <p><strong>Total Revenue:</strong> ${toCurrency(totalRevenue)}</p>
                    <p><strong>Today's Revenue:</strong> ${toCurrency(todayRevenue)}</p>
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
                    <p><strong>Total Booking Requests:</strong> ${bookings.length}</p>
                    <p><strong>Active/Approved:</strong> ${activeBookings.length}</p>
                    <p><strong>Pending:</strong> ${bookings.filter(item => String(item.status || '').toLowerCase() === 'pending').length}</p>
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
                                <option value="open">Open</option>
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
    const modal = document.getElementById('invoice-modal');
    if (modal) {
        modal.classList.remove('active');
    }
}

async function saveInvoice(e) {
    e.preventDefault();

    const client = getSupabaseClient();
    if (!client) {
        alert('Supabase is not configured.');
        return;
    }

    const invoiceNumber = document.getElementById('invoice-number').value.trim();
    const customer = document.getElementById('invoice-customer').value.trim();
    const notes = document.getElementById('invoice-description').value.trim();
    const amount = Number(document.getElementById('invoice-amount').value || 0);
    const status = document.getElementById('invoice-status').value;

    const payload = {
        invoice_no: invoiceNumber,
        customer,
        status,
        issue_date: new Date().toISOString(),
        due_date: new Date().toISOString(),
        pickup_date: new Date().toISOString(),
        return_date: new Date().toISOString(),
        total_days: 1,
        daily_rate: amount,
        sub_total: amount,
        tax_rate: 0,
        tax_amount: 0,
        total_amount: amount,
        paid_amount: status === 'paid' ? amount : 0,
        notes,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
    };

    const { error } = await client.from('invoices').insert(payload);
    if (error) {
        console.warn('Admin invoice insert failed:', error.message || error);
        alert('Could not save invoice.');
        return;
    }

    closeInvoiceModal();
    await renderInvoices();
    alert('Invoice added successfully.');
}

async function toggleInvoiceStatus(invoiceNumber) {
    const client = getSupabaseClient();
    if (!client) return;

    const { data, error } = await client
        .from('invoices')
        .select('id,status,total_amount,invoice_no')
        .eq('invoice_no', invoiceNumber)
        .limit(1);

    if (error || !Array.isArray(data) || !data.length) {
        if (error) console.warn('Invoice lookup failed:', error.message || error);
        return;
    }

    const invoice = data[0];
    const nextStatus = String(invoice.status || '').toLowerCase() === 'paid' ? 'open' : 'paid';
    const paidAmount = nextStatus === 'paid' ? Number(invoice.total_amount || 0) : 0;

    const { error: updateError } = await client
        .from('invoices')
        .update({ status: nextStatus, paid_amount: paidAmount, updated_at: new Date().toISOString() })
        .eq('id', invoice.id);

    if (updateError) {
        console.warn('Invoice status update failed:', updateError.message || updateError);
        return;
    }

    await renderInvoices();
}

async function deleteInvoice(invoiceNumber) {
    if (!confirm('Are you sure you want to delete this invoice?')) return;

    const client = getSupabaseClient();
    if (!client) return;

    const { error } = await client
        .from('invoices')
        .delete()
        .eq('invoice_no', invoiceNumber);

    if (error) {
        console.warn('Invoice delete failed:', error.message || error);
        return;
    }

    await renderInvoices();
}

async function changeVehicleStatus(vehicleId) {
    const client = getSupabaseClient();
    if (!client) return;

    const { data, error } = await client
        .from('vehicles')
        .select('id,status')
        .eq('id', Number(vehicleId))
        .limit(1);

    if (error || !Array.isArray(data) || !data.length) {
        if (error) console.warn('Vehicle lookup failed:', error.message || error);
        return;
    }

    const vehicle = data[0];
    const statuses = ['available', 'rented', 'maintenance'];
    const currentIndex = statuses.indexOf(String(vehicle.status || 'available'));
    const nextStatus = statuses[(currentIndex + 1 + statuses.length) % statuses.length];

    const { error: updateError } = await client
        .from('vehicles')
        .update({ status: nextStatus })
        .eq('id', Number(vehicleId));

    if (updateError) {
        console.warn('Vehicle status update failed:', updateError.message || updateError);
        return;
    }

    await renderInventory();
}

async function exportAllData() {
    const [fleet, bookings, invoices] = await Promise.all([fetchFleet(), fetchBookings(), fetchInvoices()]);

    const data = {
        fleet,
        booking_requests: bookings,
        invoices
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `veera-rentals-export-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
}

function printReport() {
    window.print();
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', async (e) => {
            e.preventDefault();
            const tab = link.getAttribute('data-tab');
            await showTab(tab);
        });
    });

    showTab('dashboard');
});
