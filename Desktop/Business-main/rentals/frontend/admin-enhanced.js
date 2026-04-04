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

function extractLatestServiceEventByType(notes, type) {
    const normalizedType = String(type || '').trim().toLowerCase();
    if (!normalizedType) return null;

    const payloads = extractServicePayloadsFromNotes(notes);
    if (!payloads.length) return null;

    for (let i = payloads.length - 1; i >= 0; i -= 1) {
        const payload = payloads[i];
        if (String(payload?.type || '').trim().toLowerCase() === normalizedType) {
            return payload;
        }
    }

    return null;
}

function renderBookingCard(booking, extraBadges = []) {
    const createdAt = booking.created_at || new Date().toISOString();
    const vehicleText = sanitizeText(booking.car || booking.car_name, `Vehicle #${Number(booking.vehicle_id || 0) || ''}`);
    const badgeText = [sanitizeText(booking.status, 'pending'), ...extraBadges.filter(Boolean)].join(' • ');

    return `
        <div class="booking-card ${String(booking.status || '').toLowerCase()}">
            <div class="booking-header">
                <span class="booking-type-badge">${badgeText}</span>
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
}

function renderBookingSection(title, cardsHtml, emptyText) {
    return `
        <section style="margin-bottom: 1.5rem;">
            <h3 style="font-family: 'Poppins', sans-serif; font-size: 1.15rem; margin-bottom: 0.75rem; color: #1a1a1a;">${escapeHtml(title)}</h3>
            ${cardsHtml || `<p class="empty-state">${escapeHtml(emptyText)}</p>`}
        </section>
    `;
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

async function fetchCustomers() {
    const client = getSupabaseClient();
    if (!client) return [];

    try {
        const [customersResult, bookingsResult, invoicesResult] = await Promise.all([
            client.from('customers').select('*').order('updated_at', { ascending: false }),
            client.from('booking_requests').select('*').order('created_at', { ascending: false }),
            client.from('invoices').select('*').order('created_at', { ascending: false })
        ]);

        const customers = Array.isArray(customersResult.data) ? customersResult.data : [];
        const bookings = Array.isArray(bookingsResult.data) ? bookingsResult.data : [];
        const invoices = Array.isArray(invoicesResult.data) ? invoicesResult.data : [];

        return customers.map(customer => {
            const customerId = Number(customer.id || 0);
            const linkedBookings = bookings.filter(booking => Number(booking.customer_id || booking.customerId || 0) === customerId ||
                sanitizeText(booking.email, '').toLowerCase() === sanitizeText(customer.email, '').toLowerCase() ||
                sanitizeText(booking.phone, '') === sanitizeText(customer.phone, ''));
            const linkedInvoices = invoices.filter(invoice => Number(invoice.customer_id || invoice.customerId || 0) === customerId ||
                sanitizeText(invoice.customer_email || invoice.customerEmail, '').toLowerCase() === sanitizeText(customer.email, '').toLowerCase() ||
                sanitizeText(invoice.customer_phone || invoice.customerPhone, '') === sanitizeText(customer.phone, ''));

            const sortedBookings = linkedBookings
                .slice()
                .sort((a, b) => new Date(b.created_at || b.createdAt || b.pickup_at || b.pickupDate || 0) - new Date(a.created_at || a.createdAt || a.pickup_at || a.pickupDate || 0));
            const latestBooking = sortedBookings[0] || null;
            const latestBookingPayloads = latestBooking ? extractServicePayloadsFromNotes(latestBooking.notes) : [];
            const latestServiceEvent = latestBookingPayloads.length ? latestBookingPayloads[latestBookingPayloads.length - 1] : null;

            const bookingVehicles = [...new Set(linkedBookings.map(booking => sanitizeText(booking.car || booking.car_name, 'Vehicle')).filter(Boolean))];
            const totalSpent = linkedInvoices.reduce((sum, invoice) => sum + Number(invoice.total_amount || invoice.totalAmount || 0), 0);
            const lastBookingDate = linkedBookings.length
                ? linkedBookings.reduce((latest, booking) => {
                    const bookingDate = new Date(booking.created_at || booking.createdAt || booking.pickup_at || booking.pickupDate || 0);
                    if (Number.isNaN(bookingDate.getTime())) return latest;
                    return !latest || bookingDate > latest ? bookingDate : latest;
                }, null)
                : null;

            const licensePhotoUrls = latestBooking ? extractPhotoUrlsFromNotes(latestBooking.notes) : [];

            return {
                ...customer,
                bookingCount: linkedBookings.length,
                invoiceCount: linkedInvoices.length,
                totalSpent,
                vehicles: bookingVehicles,
                currentVehicle: customer.current_vehicle || latestBooking?.car || latestBooking?.car_name || bookingVehicles[0] || null,
                lastRequestType: customer.last_request_type || latestServiceEvent?.type || latestBooking?.source || null,
                licensePhotoUrls: Array.isArray(customer.license_photo_urls) ? customer.license_photo_urls : licensePhotoUrls,
                lastBookingAt: customer.last_booking_at || lastBookingDate?.toISOString() || null
            };
        });
    } catch (error) {
        console.warn('Admin customers load exception:', error);
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
    } else if (tabName === 'customers') {
        await renderCustomers();
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

    const dropoffRequests = [];
    const swapRequests = [];
    const pickupRequests = [];

    bookings.forEach(booking => {
        const dropoffEvent = extractLatestServiceEventByType(booking.notes, 'dropoff');
        const swapEvent = extractLatestServiceEventByType(booking.notes, 'swap');

        if (dropoffEvent) {
            dropoffRequests.push({ booking, event: dropoffEvent });
        }

        if (swapEvent) {
            swapRequests.push({ booking, event: swapEvent });
        }

        const source = String(booking.source || '').toLowerCase();
        if (!dropoffEvent && !swapEvent && (source.includes('pickup') || source === '' || source === 'scanner')) {
            pickupRequests.push(booking);
        }
    });

    const pickupCards = pickupRequests.map(item => renderBookingCard(item, ['PICKUP REQUEST'])).join('');
    const dropoffCards = dropoffRequests.map(item => {
        const submittedAt = item.event?.submittedAt ? new Date(item.event.submittedAt).toLocaleString() : 'N/A';
        return renderBookingCard(item.booking, [`DROP-OFF REQUEST`, `Submitted: ${submittedAt}`]);
    }).join('');
    const swapCards = swapRequests.map(item => {
        const submittedAt = item.event?.submittedAt ? new Date(item.event.submittedAt).toLocaleString() : 'N/A';
        return renderBookingCard(item.booking, [`SWAP REQUEST`, `Submitted: ${submittedAt}`]);
    }).join('');

    bookingsGrid.innerHTML = `
        ${renderBookingSection('Pickup Requests', pickupCards, 'No pickup requests found.')}
        ${renderBookingSection('Drop-off Requests', dropoffCards, 'No drop-off requests found.')}
        ${renderBookingSection('Swap Requests', swapCards, 'No swap requests found.')}
    `;
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

// Render Customers
async function renderCustomers() {
    const customers = await fetchCustomers();
    const customersGrid = document.getElementById('customers-grid');

    if (!customersGrid) return;

    const totalBookings = customers.reduce((sum, customer) => sum + Number(customer.bookingCount || 0), 0);
    const totalSpent = customers.reduce((sum, customer) => sum + Number(customer.totalSpent || 0), 0);
    const activeCustomers = customers.filter(customer => Number(customer.bookingCount || 0) > 0).length;

    if (!customers.length) {
        customersGrid.innerHTML = `
            <div class="reports-grid">
                <div class="report-card">
                    <h3>Customer Summary</h3>
                    <div class="report-stats">
                        <p><strong>Total Customers:</strong> 0</p>
                        <p><strong>Active Customers:</strong> 0</p>
                        <p><strong>Total Bookings:</strong> 0</p>
                        <p><strong>Total Spent:</strong> ${toCurrency(0)}</p>
                    </div>
                </div>
            </div>
            <p class="empty-state">No customers found.</p>
        `;
        return;
    }

    customersGrid.innerHTML = `
        <div class="reports-grid">
            <div class="report-card">
                <h3>Customer Summary</h3>
                <div class="report-stats">
                    <p><strong>Total Customers:</strong> ${customers.length}</p>
                    <p><strong>Active Customers:</strong> ${activeCustomers}</p>
                    <p><strong>Total Bookings:</strong> ${totalBookings}</p>
                    <p><strong>Total Spent:</strong> ${toCurrency(totalSpent)}</p>
                </div>
            </div>
            <div class="report-card">
                <h3>Top Customers</h3>
                <div class="report-stats">
                    ${customers
                        .slice()
                        .sort((a, b) => Number(b.totalSpent || 0) - Number(a.totalSpent || 0))
                        .slice(0, 5)
                        .map(customer => `<p><strong>${sanitizeText(customer.full_name || customer.fullName)}</strong><br><small>${Number(customer.bookingCount || 0)} booking(s) • ${toCurrency(customer.totalSpent || 0)}</small></p>`)
                        .join('')}
                </div>
            </div>
        </div>
        <div class="inventory-list">
            ${customers.map(customer => `
                <div class="vehicle-card">
                    <div class="vehicle-header">
                        <h3>${sanitizeText(customer.full_name || customer.fullName)}</h3>
                        <span class="status-badge available">${Number(customer.bookingCount || 0)} booking(s)</span>
                    </div>
                    <div class="vehicle-details">
                        <p><strong>Phone:</strong> ${sanitizeText(customer.phone)}</p>
                        <p><strong>Email:</strong> ${sanitizeText(customer.email)}</p>
                        <p><strong>Current Vehicle:</strong> ${sanitizeText(customer.currentVehicle)}</p>
                        <p><strong>Request Type:</strong> ${sanitizeText(customer.lastRequestType)}</p>
                        <p><strong>Last Booking:</strong> ${customer.lastBookingAt ? new Date(customer.lastBookingAt).toLocaleString() : 'N/A'}</p>
                        <p><strong>Vehicles Used:</strong> ${customer.vehicles && customer.vehicles.length ? customer.vehicles.join(', ') : 'None yet'}</p>
                        <p><strong>Total Spent:</strong> ${toCurrency(customer.totalSpent || 0)}</p>
                        <p><strong>License Photos:</strong> ${customer.licensePhotoUrls && customer.licensePhotoUrls.length ? customer.licensePhotoUrls.map((url, index) => `<a href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer">Photo ${index + 1}</a>`).join(' | ') : 'None saved'}</p>
                        ${customer.notes ? `<p><strong>Notes:</strong> ${sanitizeText(customer.notes)}</p>` : ''}
                    </div>
                    <div class="invoice-actions">
                        <button class="btn btn-small" onclick="showCustomerHistory('${String(customer.id).replace(/'/g, "\\'")}')">View History</button>
                    </div>
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
    const customers = await fetchCustomers();

    const totalRevenue = invoices.reduce((sum, inv) => sum + Number(inv.total_amount || 0), 0);
    const todayRevenue = invoices.filter(inv => {
        const invDate = new Date(inv.issue_date || inv.created_at || 0).toDateString();
        return invDate === new Date().toDateString();
    }).reduce((sum, inv) => sum + Number(inv.total_amount || 0), 0);

    const utilization = fleet.length > 0
        ? ((fleet.filter(v => v.status === 'rented').length / fleet.length) * 100).toFixed(1)
        : 0;

    const activeBookings = bookings.filter(item => ['active', 'approved'].includes(String(item.status || '').toLowerCase()));
    const bookedCustomers = customers.filter(customer => Number(customer.bookingCount || 0) > 0).length;
    const topVehicle = fleet.map(vehicle => {
        const vehicleBookings = bookings.filter(booking => Number(booking.vehicle_id || booking.carId || 0) === Number(vehicle.id));
        const vehicleRevenue = invoices
            .filter(invoice => Number(invoice.car_id || invoice.carId || 0) === Number(vehicle.id))
            .reduce((sum, invoice) => sum + Number(invoice.total_amount || invoice.totalAmount || 0), 0);

        return {
            name: sanitizeText(vehicle.name, `${sanitizeText(vehicle.make, '')} ${sanitizeText(vehicle.model, '')}`.trim() || 'Vehicle'),
            bookings: vehicleBookings.length,
            revenue: vehicleRevenue
        };
    }).sort((a, b) => b.bookings - a.bookings)[0];

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
                    ${topVehicle ? `<p><strong>Top Vehicle:</strong> ${topVehicle.name} (${topVehicle.bookings} booking(s), ${toCurrency(topVehicle.revenue)})</p>` : ''}
                </div>
            </div>
            <div class="report-card">
                <h3>Booking & Customer Activity</h3>
                <div class="report-stats">
                    <p><strong>Total Booking Requests:</strong> ${bookings.length}</p>
                    <p><strong>Active/Approved:</strong> ${activeBookings.length}</p>
                    <p><strong>Pending:</strong> ${bookings.filter(item => String(item.status || '').toLowerCase() === 'pending').length}</p>
                    <p><strong>Customers With Bookings:</strong> ${bookedCustomers}</p>
                    <p><strong>Customer Records:</strong> ${customers.length}</p>
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

async function showCustomerHistory(customerId) {
    const customers = await fetchCustomers();
    const customer = customers.find(item => Number(item.id) === Number(customerId));
    if (!customer) {
        alert('Customer not found.');
        return;
    }

    const bookings = await fetchBookings();
    const invoices = await fetchInvoices();
    const customerBookings = bookings.filter(booking => Number(booking.customer_id || booking.customerId || 0) === Number(customer.id) ||
        sanitizeText(booking.email, '').toLowerCase() === sanitizeText(customer.email, '').toLowerCase() ||
        sanitizeText(booking.phone, '') === sanitizeText(customer.phone, ''));
    const customerInvoices = invoices.filter(invoice => Number(invoice.customer_id || invoice.customerId || 0) === Number(customer.id) ||
        sanitizeText(invoice.customer_email || invoice.customerEmail, '').toLowerCase() === sanitizeText(customer.email, '').toLowerCase() ||
        sanitizeText(invoice.customer_phone || invoice.customerPhone, '') === sanitizeText(customer.phone, ''));

    const historyText = [
        `Customer: ${sanitizeText(customer.full_name || customer.fullName)}`,
        `Phone: ${sanitizeText(customer.phone)}`,
        `Email: ${sanitizeText(customer.email)}`,
        `Bookings: ${customerBookings.length}`,
        `Invoices: ${customerInvoices.length}`,
        `Total Spent: ${toCurrency(customer.totalSpent || 0)}`,
        '',
        'Booking History:',
        ...customerBookings.map(booking => `- ${sanitizeText(booking.car || booking.car_name, 'Vehicle')} | ${booking.pickup_at || booking.pickupDate || 'N/A'} -> ${booking.return_at || booking.returnDate || 'N/A'} | ${sanitizeText(booking.status, 'pending')}`),
        '',
        'Invoice History:',
        ...customerInvoices.map(invoice => `- ${sanitizeText(invoice.invoice_no || invoice.invoiceNumber, 'N/A')} | ${toCurrency(invoice.total_amount || invoice.totalAmount)} | ${sanitizeText(invoice.status, 'open')}`)
    ].join('\n');

    alert(historyText);
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
