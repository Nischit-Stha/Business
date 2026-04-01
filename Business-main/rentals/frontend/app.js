// ===== DATA STORAGE =====
let fleet = [];

let rentals = [];
let invoices = [];
let bookingRequestsCache = [];
let priceOffersCache = [];

const DEFAULT_RATE = 250;
const BOOKING_REQUESTS_KEY = 'booking-requests-data';
const INVOICES_KEY = 'rentals-invoices-data';
const PRICE_OFFERS_KEY = 'price-offers-data';
const DATABASE_ONLY_MODE = true;
const LOCAL_CACHE_RESET_QUERY_PARAM = 'resetLocalData';
const CLEAR_CARS_QUERY_PARAM = 'clearCars';
const LOCAL_DATA_KEYS = [
    'fleet-data',
    'rentals-data',
    INVOICES_KEY,
    BOOKING_REQUESTS_KEY,
    PRICE_OFFERS_KEY,
    'veera-rentals-pickups',
    'veera-rentals-dropoffs',
    'veera-rentals-swaps',
    'records-imported-v1'
];
let activeFleetFilter = 'all';
let fleetSearchQuery = '';
let fleetSortMode = 'name-asc';
let bookingSearchQuery = '';
let bookingStatusFilter = 'active';
let bookingSortMode = 'recent';
let revenueRangeDays = 14;
let bookingQuickFilterMode = 'all';
let requestSearchQuery = '';
let requestSortMode = 'newest';
let activeNegotiationOfferId = null;
let suppressRemoteSync = false;

function normalizeCarRate(rate) {
    const numericRate = Number(rate);
    if (!Number.isFinite(numericRate) || numericRate <= 0) {
        return DEFAULT_RATE;
    }
    return numericRate;
}

function normalizeFleetRates() {
    let changed = false;
    fleet = fleet.map(car => {
        const normalizedRate = normalizeCarRate(car.rate);
        if (Number(car.rate) !== normalizedRate) {
            changed = true;
            return { ...car, rate: normalizedRate };
        }
        return car;
    });
    return changed;
}

function parseAvailabilityCalendar(rawText = '') {
    if (!rawText) return [];

    return String(rawText)
        .split('\n')
        .map(line => line.trim())
        .filter(Boolean)
        .map(line => {
            const [rangePart, ...noteParts] = line.split('|');
            const [startPart, endPart] = String(rangePart || '').split('to').map(item => item.trim());
            const startDate = new Date(startPart);
            const endDate = new Date(endPart || startPart);

            if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
                return null;
            }

            return {
                start: startDate.toISOString(),
                end: endDate.toISOString(),
                note: noteParts.join('|').trim() || 'Blocked'
            };
        })
        .filter(Boolean);
}

function formatAvailabilityCalendar(calendarEntries = []) {
    if (!Array.isArray(calendarEntries) || !calendarEntries.length) return '';

    return calendarEntries
        .map(entry => {
            const start = new Date(entry.start);
            const end = new Date(entry.end);
            if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return null;
            const startText = start.toISOString().slice(0, 10);
            const endText = end.toISOString().slice(0, 10);
            return `${startText} to ${endText} | ${entry.note || 'Blocked'}`;
        })
        .filter(Boolean)
        .join('\n');
}

function normalizeCarRecord(car) {
    const dayRate = normalizeCarRate(car.priceDay ?? car.rate);
    const weekRate = Number(car.priceWeek);
    return {
        ...car,
        rate: dayRate,
        priceDay: dayRate,
        priceWeek: Number.isFinite(weekRate) && weekRate > 0 ? weekRate : Number((dayRate * 6).toFixed(2)),
        location: hasMeaningfulValue(car.location) ? String(car.location).trim() : 'Main Branch',
        images: Array.isArray(car.images) ? car.images.filter(Boolean).slice(0, 8) : [],
        availabilityCalendar: Array.isArray(car.availabilityCalendar) ? car.availabilityCalendar : []
    };
}

function normalizeFleetRecords() {
    fleet = fleet.map(normalizeCarRecord);
}

function readImageFilesAsDataUrls(fileList) {
    return Promise.all(Array.from(fileList || []).map(file => new Promise((resolve) => {
        const reader = new FileReader();
        reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : '');
        reader.onerror = () => resolve('');
        reader.readAsDataURL(file);
    })));
}

function getAvailabilitySummary(car) {
    const now = new Date();
    const calendar = Array.isArray(car.availabilityCalendar) ? car.availabilityCalendar : [];
    const upcoming = calendar
        .map(entry => ({
            ...entry,
            startDate: new Date(entry.start),
            endDate: new Date(entry.end)
        }))
        .filter(entry => !Number.isNaN(entry.startDate.getTime()) && !Number.isNaN(entry.endDate.getTime()) && entry.endDate >= now)
        .sort((a, b) => a.startDate - b.startDate);

    if (!upcoming.length) {
        return 'Open calendar';
    }

    const first = upcoming[0];
    return `Blocked ${first.startDate.toLocaleDateString()} - ${first.endDate.toLocaleDateString()}`;
}

function isDateRangeOverlapping(firstStart, firstEnd, secondStart, secondEnd) {
    const startA = new Date(firstStart);
    const endA = new Date(firstEnd);
    const startB = new Date(secondStart);
    const endB = new Date(secondEnd);

    if ([startA, endA, startB, endB].some(date => Number.isNaN(date.getTime()))) {
        return false;
    }

    return startA <= endB && startB <= endA;
}

function getBookingRequests() {
    if (DATABASE_ONLY_MODE) {
        return Array.isArray(bookingRequestsCache) ? bookingRequestsCache : [];
    }

    try {
        const raw = localStorage.getItem(BOOKING_REQUESTS_KEY);
        const parsed = raw ? JSON.parse(raw) : [];
        return Array.isArray(parsed) ? parsed : [];
    } catch {
        return [];
    }
}

function saveBookingRequests(requests) {
    bookingRequestsCache = Array.isArray(requests) ? requests : [];
    if (!DATABASE_ONLY_MODE) {
        localStorage.setItem(BOOKING_REQUESTS_KEY, JSON.stringify(bookingRequestsCache));
    }
    void syncBookingRequestsToSupabase(requests);
}

function getPriceOffers() {
    if (DATABASE_ONLY_MODE) {
        return Array.isArray(priceOffersCache) ? priceOffersCache : [];
    }

    try {
        const raw = localStorage.getItem(PRICE_OFFERS_KEY);
        const parsed = raw ? JSON.parse(raw) : [];
        return Array.isArray(parsed) ? parsed : [];
    } catch {
        return [];
    }
}

function savePriceOffers(offers) {
    priceOffersCache = Array.isArray(offers) ? offers : [];
    if (!DATABASE_ONLY_MODE) {
        localStorage.setItem(PRICE_OFFERS_KEY, JSON.stringify(priceOffersCache));
    }
    void syncPriceOffersToSupabase(offers);
}

function ensureOfferConversation(offer) {
    if (!offer || typeof offer !== 'object') return offer;

    if (!Array.isArray(offer.negotiationMessages)) {
        offer.negotiationMessages = [];
    }

    if (!offer.negotiationMessages.length) {
        const openingMessage = offer.note || `Initial offer: $${Number(offer.offeredRate || 0).toFixed(2)}/day against listed $${Number(offer.listedRate || 0).toFixed(2)}/day`;
        offer.negotiationMessages.push({
            id: `msg-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
            sender: 'customer',
            type: 'offer',
            text: openingMessage,
            timestamp: offer.createdAt || new Date().toISOString()
        });
    }

    return offer;
}

function addOfferMessage(offer, sender, text, type = 'message') {
    if (!offer || !text) return;
    ensureOfferConversation(offer);
    offer.negotiationMessages.push({
        id: `msg-${Date.now()}-${Math.floor(Math.random() * 100000)}`,
        sender,
        type,
        text,
        timestamp: new Date().toISOString()
    });
}

function normalizeRentalDates(rentalList = []) {
    return rentalList.map(r => ({
        ...r,
        pickupDate: new Date(r.pickupDate),
        returnDate: new Date(r.returnDate)
    }));
}

function syncRentalsFromBookingRequestsCache() {
    if (!DATABASE_ONLY_MODE) return;

    rentals = bookingRequestsCache
        .filter(request => {
            const status = String(request.status || '').toLowerCase();
            return status === 'active' || status === 'completed';
        })
        .map(request => ({
            id: Number(request.id),
            customer: request.customer || 'Customer',
            phone: request.phone || 'N/A',
            email: request.email || '',
            car: request.car || 'Vehicle',
            carId: Number(request.carId || 0) || null,
            pickupDate: new Date(request.pickupDate),
            returnDate: new Date(request.returnDate),
            notes: request.notes || '',
            status: String(request.status || 'active').toLowerCase(),
            source: request.source || 'customer-portal',
            createdAt: request.createdAt || new Date().toISOString(),
            approvedAt: request.approvedAt || null
        }));
}

function clearLocalRentalData() {
    LOCAL_DATA_KEYS.forEach(key => localStorage.removeItem(key));
}

function shouldResetLocalCacheFromUrl() {
    try {
        const params = new URLSearchParams(window.location.search || '');
        return params.get(LOCAL_CACHE_RESET_QUERY_PARAM) === '1';
    } catch {
        return false;
    }
}

function shouldClearCarsFromUrl() {
    try {
        const params = new URLSearchParams(window.location.search || '');
        return params.get(CLEAR_CARS_QUERY_PARAM) === '1';
    } catch {
        return false;
    }
}

function removeResetParamFromUrl() {
    try {
        const url = new URL(window.location.href);
        if (!url.searchParams.has(LOCAL_CACHE_RESET_QUERY_PARAM) && !url.searchParams.has(CLEAR_CARS_QUERY_PARAM)) return;
        url.searchParams.delete(LOCAL_CACHE_RESET_QUERY_PARAM);
        url.searchParams.delete(CLEAR_CARS_QUERY_PARAM);
        window.history.replaceState({}, '', `${url.pathname}${url.search}${url.hash}`);
    } catch {
        // Ignore URL cleanup errors.
    }
}

window.resetLocalRentalData = function resetLocalRentalData() {
    clearLocalRentalData();
    window.location.reload();
};

async function clearFleetDataEverywhere() {
    fleet = [];
    localStorage.removeItem('fleet-data');
    localStorage.setItem('records-imported-v1', 'true');

    const client = getSupabaseClient();
    if (!client) {
        return { remoteDeleted: false };
    }

    try {
        const { error } = await client
            .from('vehicles')
            .delete()
            .gte('id', 0);

        if (error) {
            console.warn('Supabase vehicles delete failed:', error.message || error);
            return { remoteDeleted: false };
        }

        return { remoteDeleted: true };
    } catch (error) {
        console.warn('Supabase vehicles delete exception:', error);
        return { remoteDeleted: false };
    }
}

window.clearAllCarsData = async function clearAllCarsData() {
    await clearFleetDataEverywhere();
    window.location.reload();
};

function getSupabaseClient() {
    if (typeof window.getVeeraSupabaseClient === 'function') {
        return window.getVeeraSupabaseClient();
    }
    return null;
}

function mapSupabaseVehicleToLocal(vehicle) {
    return normalizeCarRecord({
        id: Number(vehicle.id),
        name: vehicle.name,
        make: vehicle.make,
        model: vehicle.model,
        license: vehicle.plate,
        rego: vehicle.plate,
        status: vehicle.status || 'available',
        rate: Number(vehicle.rate_day || DEFAULT_RATE),
        priceDay: Number(vehicle.rate_day || DEFAULT_RATE),
        priceWeek: Number(vehicle.rate_week || 0),
        location: vehicle.location || 'Main Branch',
        images: Array.isArray(vehicle.images) ? vehicle.images : [],
        availabilityCalendar: Array.isArray(vehicle.availability) ? vehicle.availability : []
    });
}

function mapSupabaseBookingRequestToLocal(request) {
    return {
        id: Number(request.id),
        customer: request.customer || request.customer_name || 'Customer',
        phone: request.phone || request.customer_phone || 'N/A',
        email: request.email || request.customer_email || 'N/A',
        car: request.car || request.car_name || `Vehicle #${Number(request.vehicle_id || 0) || ''}`.trim(),
        carId: Number(request.vehicle_id || request.car_id || 0) || null,
        pickupDate: request.pickup_at ? new Date(request.pickup_at) : new Date(),
        returnDate: request.return_at ? new Date(request.return_at) : new Date(),
        notes: request.notes || '',
        status: request.status || 'pending',
        source: request.source || 'customer-portal',
        createdAt: request.created_at || new Date().toISOString()
    };
}

function mapSupabaseOfferToLocal(offer) {
    return {
        id: Number(offer.id),
        customerId: Number(offer.customer_id || 0) || null,
        customerName: offer.customer_name || 'Customer',
        customerEmail: offer.customer_email || '',
        customerPhone: offer.customer_phone || '',
        carId: Number(offer.vehicle_id || 0) || null,
        carName: offer.car_name || `Vehicle #${Number(offer.vehicle_id || 0) || ''}`.trim(),
        carModel: offer.car_model || '',
        listedRate: Number(offer.listed_rate || 0),
        offeredRate: Number(offer.offered_rate || 0),
        note: offer.note || '',
        status: offer.status || 'pending',
        ownerResponse: offer.owner_response || '',
        counterRate: Number(offer.counter_rate || 0) || null,
        createdAt: offer.created_at || new Date().toISOString(),
        updatedAt: offer.updated_at || null,
        negotiationMessages: []
    };
}

function mapSupabaseInvoiceToLocal(invoice) {
    const toIsoDate = (value, fallback = new Date().toISOString()) => {
        if (!value) return fallback;
        const parsed = new Date(value);
        return Number.isNaN(parsed.getTime()) ? fallback : parsed.toISOString();
    };

    const createdAt = toIsoDate(invoice.created_at || invoice.issue_date || invoice.createdAt || invoice.issueDate);
    const issueDate = toIsoDate(invoice.issue_date || invoice.issueDate || createdAt, createdAt);
    const dueDate = toIsoDate(invoice.due_date || invoice.dueDate || issueDate, issueDate);
    const pickupDate = toIsoDate(invoice.pickup_date || invoice.pickupDate || issueDate, issueDate);
    const returnDate = toIsoDate(invoice.return_date || invoice.returnDate || dueDate, dueDate);

    return {
        id: Number(invoice.id || 0) || Date.now(),
        invoiceNumber: invoice.invoice_no || invoice.invoice_number || invoice.invoiceNumber || `INV-${new Date(issueDate).getFullYear()}-${String(invoice.id || '00000').padStart(5, '0')}`,
        rentalId: Number(invoice.rental_id || invoice.rentalId || invoice.booking_request_id || 0) || null,
        customer: invoice.customer || 'Customer',
        customerPhone: invoice.customer_phone || invoice.customerPhone || 'N/A',
        customerEmail: invoice.customer_email || invoice.customerEmail || 'N/A',
        carId: Number(invoice.car_id || invoice.carId || 0) || null,
        carName: invoice.car_name || invoice.carName || 'Vehicle',
        status: invoice.status || 'open',
        issueDate,
        dueDate,
        pickupDate,
        returnDate,
        totalDays: Number(invoice.total_days || invoice.totalDays || 0) || 0,
        dailyRate: Number(invoice.daily_rate || invoice.dailyRate || 0) || 0,
        subTotal: Number(invoice.sub_total || invoice.subTotal || 0) || 0,
        taxRate: Number(invoice.tax_rate || invoice.taxRate || 0) || 0,
        taxAmount: Number(invoice.tax_amount || invoice.taxAmount || 0) || 0,
        totalAmount: Number(invoice.total_amount || invoice.totalAmount || 0) || 0,
        paidAmount: Number(invoice.paid_amount || invoice.paidAmount || 0) || 0,
        notes: invoice.notes || '',
        createdAt,
        updatedAt: toIsoDate(invoice.updated_at || invoice.updatedAt || createdAt, createdAt)
    };
}

function mapLocalInvoiceToSupabase(invoice) {
    const toIsoDate = (value) => {
        const parsed = new Date(value);
        return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
    };

    return {
        id: Number(invoice.id || 0) || null,
        rental_id: Number(invoice.rentalId || 0) || null,
        invoice_no: invoice.invoiceNumber || null,
        customer: invoice.customer || null,
        customer_phone: invoice.customerPhone || null,
        customer_email: invoice.customerEmail || null,
        car_id: Number(invoice.carId || 0) || null,
        car_name: invoice.carName || null,
        status: invoice.status || 'open',
        issue_date: toIsoDate(invoice.issueDate || invoice.createdAt),
        due_date: toIsoDate(invoice.dueDate || invoice.issueDate || invoice.createdAt),
        pickup_date: toIsoDate(invoice.pickupDate || invoice.issueDate || invoice.createdAt),
        return_date: toIsoDate(invoice.returnDate || invoice.dueDate || invoice.issueDate || invoice.createdAt),
        total_days: Number(invoice.totalDays || 0) || 0,
        daily_rate: Number(invoice.dailyRate || 0) || 0,
        sub_total: Number(invoice.subTotal || 0) || 0,
        tax_rate: Number(invoice.taxRate || 0) || 0,
        tax_amount: Number(invoice.taxAmount || 0) || 0,
        total_amount: Number(invoice.totalAmount || 0) || 0,
        paid_amount: Number(invoice.paidAmount || 0) || 0,
        notes: invoice.notes || null,
        created_at: toIsoDate(invoice.createdAt || invoice.issueDate),
        updated_at: toIsoDate(invoice.updatedAt || invoice.createdAt || invoice.issueDate)
    };
}

function mapLocalOfferToSupabase(offer) {
    return {
        id: Number(offer.id),
        customer_id: Number(offer.customerId || 0) || null,
        customer_name: offer.customerName || null,
        customer_email: offer.customerEmail || null,
        customer_phone: offer.customerPhone || null,
        vehicle_id: Number(offer.carId || 0) || null,
        car_name: offer.carName || null,
        car_model: offer.carModel || null,
        listed_rate: Number(offer.listedRate || 0),
        offered_rate: Number(offer.offeredRate || 0),
        note: offer.note || null,
        status: offer.status || 'pending',
        owner_response: offer.ownerResponse || null,
        counter_rate: Number(offer.counterRate || 0) || null,
        created_at: offer.createdAt ? new Date(offer.createdAt).toISOString() : new Date().toISOString(),
        updated_at: offer.updatedAt ? new Date(offer.updatedAt).toISOString() : new Date().toISOString()
    };
}

function mapLocalOfferMessageToSupabase(offerId, message) {
    return {
        offer_id: Number(offerId),
        sender_role: message.sender || 'customer',
        message: message.text || '',
        message_type: message.type || 'message',
        created_at: message.timestamp ? new Date(message.timestamp).toISOString() : new Date().toISOString()
    };
}

function mapLocalVehicleToSupabase(vehicle) {
    return {
        id: Number(vehicle.id),
        name: vehicle.name || null,
        make: vehicle.make || null,
        model: vehicle.model || null,
        plate: vehicle.license || vehicle.rego || null,
        status: vehicle.status || 'available',
        rate_day: Number(vehicle.priceDay ?? vehicle.rate ?? DEFAULT_RATE),
        rate_week: Number(vehicle.priceWeek || 0),
        location: hasMeaningfulValue(vehicle.location) ? String(vehicle.location).trim() : 'Main Branch',
        images: Array.isArray(vehicle.images) ? vehicle.images.filter(Boolean).slice(0, 8) : [],
        availability: Array.isArray(vehicle.availabilityCalendar) ? vehicle.availabilityCalendar : []
    };
}

async function syncFleetToSupabase(fleetList) {
    const client = getSupabaseClient();
    if (!client || !Array.isArray(fleetList)) return;

    try {
        const payload = fleetList
            .map(normalizeCarRecord)
            .map(mapLocalVehicleToSupabase)
            .filter(item => Number.isFinite(Number(item.id)) && Number(item.id) > 0);

        if (payload.length) {
            const { error: upsertError } = await client
                .from('vehicles')
                .upsert(payload, { onConflict: 'id' });

            if (upsertError) {
                console.warn('Supabase vehicles upsert failed:', upsertError.message || upsertError);
                return;
            }
        }

        const { data: remoteRows, error: remoteError } = await client
            .from('vehicles')
            .select('id');

        if (remoteError || !Array.isArray(remoteRows)) {
            if (remoteError) {
                console.warn('Supabase vehicles id-read failed:', remoteError.message || remoteError);
            }
            return;
        }

        const localIds = new Set(payload.map(item => Number(item.id)));
        const staleIds = remoteRows
            .map(row => Number(row.id))
            .filter(id => Number.isFinite(id) && !localIds.has(id));

        if (staleIds.length) {
            const { error: deleteError } = await client
                .from('vehicles')
                .delete()
                .in('id', staleIds);

            if (deleteError) {
                console.warn('Supabase vehicles stale-delete failed:', deleteError.message || deleteError);
            }
        }
    } catch (error) {
        console.warn('Supabase vehicles sync exception:', error);
    }
}

async function loadPriceOffersFromSupabase() {
    const client = getSupabaseClient();
    if (!client) return null;

    try {
        const { data: offersData, error: offersError } = await client
            .from('offers')
            .select('*')
            .order('created_at', { ascending: false });

        if (offersError) {
            console.warn('Supabase offers read failed:', offersError.message || offersError);
            return null;
        }

        if (!Array.isArray(offersData)) {
            return null;
        }

        const localOffers = offersData.map(mapSupabaseOfferToLocal);
        const offerIds = localOffers.map(offer => Number(offer.id)).filter(Boolean);

        if (offerIds.length) {
            const { data: messageRows, error: messageError } = await client
                .from('offer_messages')
                .select('*')
                .in('offer_id', offerIds)
                .order('created_at', { ascending: true });

            if (!messageError && Array.isArray(messageRows)) {
                const grouped = new Map();
                messageRows.forEach(row => {
                    const list = grouped.get(Number(row.offer_id)) || [];
                    list.push({
                        id: `msg-${Number(row.id || 0)}-${Number(row.offer_id || 0)}`,
                        sender: row.sender_role || 'customer',
                        type: row.message_type || 'message',
                        text: row.message || '',
                        timestamp: row.created_at || new Date().toISOString()
                    });
                    grouped.set(Number(row.offer_id), list);
                });

                localOffers.forEach(offer => {
                    offer.negotiationMessages = grouped.get(Number(offer.id)) || [];
                    ensureOfferConversation(offer);
                });
            }
        }

        return localOffers;
    } catch (error) {
        console.warn('Supabase offers read exception:', error);
        return null;
    }
}

async function syncPriceOffersToSupabase(offers) {
    const client = getSupabaseClient();
    if (!client || !Array.isArray(offers)) return;

    try {
        const payload = offers.map(mapLocalOfferToSupabase);
        const { error: offersError } = await client
            .from('offers')
            .upsert(payload, { onConflict: 'id' });

        if (offersError) {
            console.warn('Supabase offers upsert failed:', offersError.message || offersError);
            return;
        }

        for (const offer of offers) {
            const offerId = Number(offer.id);
            if (!offerId) continue;

            const { error: deleteError } = await client
                .from('offer_messages')
                .delete()
                .eq('offer_id', offerId);

            if (deleteError) {
                console.warn(`Supabase offer_messages delete failed for offer ${offerId}:`, deleteError.message || deleteError);
                continue;
            }

            const messages = (Array.isArray(offer.negotiationMessages) ? offer.negotiationMessages : [])
                .map(message => mapLocalOfferMessageToSupabase(offerId, message))
                .filter(message => message.message);

            if (!messages.length) continue;

            const { error: insertError } = await client
                .from('offer_messages')
                .insert(messages);

            if (insertError) {
                console.warn(`Supabase offer_messages insert failed for offer ${offerId}:`, insertError.message || insertError);
            }
        }
    } catch (error) {
        console.warn('Supabase offers upsert exception:', error);
    }
}

async function loadInvoicesFromSupabase() {
    const client = getSupabaseClient();
    if (!client) return null;

    try {
        const { data, error } = await client
            .from('invoices')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            console.warn('Supabase invoices read failed:', error.message || error);
            return null;
        }

        if (!Array.isArray(data)) {
            return null;
        }

        return data.map(mapSupabaseInvoiceToLocal);
    } catch (error) {
        console.warn('Supabase invoices read exception:', error);
        return null;
    }
}

async function syncInvoicesToSupabase(invoiceList) {
    const client = getSupabaseClient();
    if (!client || !Array.isArray(invoiceList)) return;

    try {
        const payload = invoiceList.map(mapLocalInvoiceToSupabase).filter(item => item.id !== null);
        if (!payload.length) return;

        const { error } = await client
            .from('invoices')
            .upsert(payload, { onConflict: 'id' });

        if (error) {
            console.warn('Supabase invoices upsert failed:', error.message || error);
        }
    } catch (error) {
        console.warn('Supabase invoices upsert exception:', error);
    }
}

function mapLocalBookingRequestToSupabase(request) {
    return {
        id: Number(request.id),
        customer: request.customer || null,
        phone: request.phone || null,
        email: request.email || null,
        car: request.car || null,
        vehicle_id: Number(request.carId || 0) || null,
        pickup_at: request.pickupDate ? new Date(request.pickupDate).toISOString() : null,
        return_at: request.returnDate ? new Date(request.returnDate).toISOString() : null,
        notes: request.notes || null,
        status: request.status || 'pending',
        source: request.source || 'customer-portal',
        created_at: request.createdAt ? new Date(request.createdAt).toISOString() : new Date().toISOString()
    };
}

async function loadBookingRequestsFromSupabase() {
    const client = getSupabaseClient();
    if (!client) return null;

    try {
        const { data, error } = await client
            .from('booking_requests')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            console.warn('Supabase booking requests read failed:', error.message || error);
            return null;
        }

        if (!Array.isArray(data)) {
            return null;
        }

        return data.map(mapSupabaseBookingRequestToLocal);
    } catch (error) {
        console.warn('Supabase booking requests read exception:', error);
        return null;
    }
}

async function syncBookingRequestsToSupabase(requests) {
    const client = getSupabaseClient();
    if (!client || !Array.isArray(requests)) return;

    try {
        const payload = requests.map(mapLocalBookingRequestToSupabase);
        const { error } = await client
            .from('booking_requests')
            .upsert(payload, { onConflict: 'id' });

        if (error) {
            console.warn('Supabase booking requests upsert failed:', error.message || error);
            return;
        }

        const { data: remoteRows, error: remoteError } = await client
            .from('booking_requests')
            .select('id');

        if (remoteError || !Array.isArray(remoteRows)) {
            if (remoteError) {
                console.warn('Supabase booking requests id-read failed:', remoteError.message || remoteError);
            }
            return;
        }

        const localIds = new Set(payload.map(item => Number(item.id)).filter(id => Number.isFinite(id) && id > 0));
        const staleIds = remoteRows
            .map(row => Number(row.id))
            .filter(id => Number.isFinite(id) && !localIds.has(id));

        if (staleIds.length) {
            const { error: deleteError } = await client
                .from('booking_requests')
                .delete()
                .in('id', staleIds);

            if (deleteError) {
                console.warn('Supabase booking requests stale-delete failed:', deleteError.message || deleteError);
            }
        }
    } catch (error) {
        console.warn('Supabase booking requests upsert exception:', error);
    }
}

async function loadFleetFromSupabase() {
    const client = getSupabaseClient();
    if (!client) return null;

    try {
        const { data, error } = await client
            .from('vehicles')
            .select('id,name,make,model,plate,status,rate_day,rate_week,location,images,availability')
            .order('id', { ascending: true });

        if (error) {
            console.warn('Supabase vehicles read failed:', error.message || error);
            return null;
        }

        if (!Array.isArray(data) || !data.length) {
            return [];
        }

        return data.map(mapSupabaseVehicleToLocal);
    } catch (error) {
        console.warn('Supabase vehicles read exception:', error);
        return null;
    }
}

async function importSeedDataFromRecords() {
    const response = await fetch('../records-seed.json', { cache: 'no-store' });
    if (!response.ok) {
        throw new Error('Seed file unavailable');
    }

    const seedData = await response.json();
    if (Array.isArray(seedData.fleet) && seedData.fleet.length > 0) {
        fleet = seedData.fleet.map(car => ({
            ...car,
            rate: normalizeCarRate(car.rate)
        }));
        normalizeFleetRecords();
    }
    if (Array.isArray(seedData.rentals) && seedData.rentals.length > 0) {
        rentals = normalizeRentalDates(seedData.rentals);
    }
    invoices = [];

    saveData({ syncRemote: false });
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
        renderRentedCarsDetails();
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
    if (shouldClearCarsFromUrl()) {
        await clearFleetDataEverywhere();
        removeResetParamFromUrl();
    }

    if (shouldResetLocalCacheFromUrl()) {
        clearLocalRentalData();
        localStorage.setItem('records-imported-v1', 'true');
        removeResetParamFromUrl();
    }

    suppressRemoteSync = true;
    if (!DATABASE_ONLY_MODE) {
        const savedFleet = localStorage.getItem('fleet-data');
        const savedRentals = localStorage.getItem('rentals-data');
        const importedFlag = localStorage.getItem('records-imported-v1') === 'true';
        const savedInvoices = localStorage.getItem(INVOICES_KEY);

        if (!importedFlag) {
            try {
                await importSeedDataFromRecords();
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
        if (savedInvoices) {
            try {
                const parsedInvoices = JSON.parse(savedInvoices);
                invoices = Array.isArray(parsedInvoices) ? parsedInvoices : [];
            } catch {
                invoices = [];
            }
        }
    }

    if (normalizeFleetRates()) {
        saveData({ syncRemote: false });
    }
    normalizeFleetRecords();

    const supabaseFleet = await loadFleetFromSupabase();
    if (Array.isArray(supabaseFleet) && supabaseFleet.length > 0) {
        fleet = supabaseFleet;
        normalizeFleetRecords();
        saveData({ syncRemote: false });
    }

    const supabaseRequests = await loadBookingRequestsFromSupabase();
    if (Array.isArray(supabaseRequests)) {
        bookingRequestsCache = supabaseRequests;
        syncRentalsFromBookingRequestsCache();
        if (!DATABASE_ONLY_MODE && supabaseRequests.length > 0) {
            localStorage.setItem(BOOKING_REQUESTS_KEY, JSON.stringify(supabaseRequests));
        }
    }

    const supabaseOffers = await loadPriceOffersFromSupabase();
    if (Array.isArray(supabaseOffers)) {
        priceOffersCache = supabaseOffers;
        if (!DATABASE_ONLY_MODE && supabaseOffers.length > 0) {
            localStorage.setItem(PRICE_OFFERS_KEY, JSON.stringify(supabaseOffers));
        }
    }

    const supabaseInvoices = await loadInvoicesFromSupabase();
    if (Array.isArray(supabaseInvoices)) {
        invoices = supabaseInvoices;
        if (!DATABASE_ONLY_MODE && supabaseInvoices.length > 0) {
            localStorage.setItem(INVOICES_KEY, JSON.stringify(supabaseInvoices));
        }
    }

    suppressRemoteSync = false;

    if (Array.isArray(supabaseFleet) && supabaseFleet.length === 0 && fleet.length > 0) {
        void syncFleetToSupabase(fleet);
    }
}

function saveData(options = {}) {
    const { syncRemote = true } = options;
    if (!DATABASE_ONLY_MODE) {
        localStorage.setItem('fleet-data', JSON.stringify(fleet));
        localStorage.setItem('rentals-data', JSON.stringify(rentals));
        localStorage.setItem(INVOICES_KEY, JSON.stringify(invoices));
    }
    if (!suppressRemoteSync && syncRemote) {
        void syncInvoicesToSupabase(invoices);
        void syncFleetToSupabase(fleet);
    }
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

function showTabSection(targetId) {
    const validTabs = new Set(['dashboard', 'bookings', 'fleet', 'reports']);
    const activeTab = validTabs.has(targetId) ? targetId : 'dashboard';

    document.querySelectorAll('[data-tab-panel]').forEach(panel => {
        panel.hidden = panel.getAttribute('data-tab-panel') !== activeTab;
    });

    setActiveNavLink(activeTab);
    window.history.replaceState(null, '', `#${activeTab}`);
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
            showTabSection(targetId);
        });
    });

    const initialHash = window.location.hash?.replace('#', '');
    showTabSection(initialHash || 'dashboard');
}

function setActiveFleetFilterButton(filter) {
    document.querySelectorAll('.filter-btn').forEach(button => {
        button.classList.toggle('active', button.dataset.filter === filter);
    });
}

function applyFleetFilter(filter, options = {}) {
    const { scrollToFleet = false } = options;
    activeFleetFilter = filter || 'all';
    setActiveFleetFilterButton(filter);
    renderFleet();

    if (scrollToFleet) {
        showTabSection('fleet');
    }
}

function isSameCalendarDate(firstDate, secondDate) {
    return firstDate.getFullYear() === secondDate.getFullYear()
        && firstDate.getMonth() === secondDate.getMonth()
        && firstDate.getDate() === secondDate.getDate();
}

function getOperationalInsights() {
    const now = new Date();
    const bookingRequests = getBookingRequests();
    const priceOffers = getPriceOffers();

    const activeRentals = rentals.filter(rental => (rental.status || 'active') === 'active');
    const overdueReturns = activeRentals.filter(rental => new Date(rental.returnDate) < now).length;
    const dueSoonReturns = activeRentals.filter(rental => {
        const returnDate = new Date(rental.returnDate);
        const hours = (returnDate - now) / (1000 * 60 * 60);
        return hours >= 0 && hours <= 24;
    }).length;
    const returnsToday = activeRentals.filter(rental => isSameCalendarDate(new Date(rental.returnDate), now)).length;
    const pendingApprovals = bookingRequests.filter(request => String(request.status || 'pending').toLowerCase() === 'pending').length;
    const pendingBargains = priceOffers.filter(offer => String(offer.status || 'pending').toLowerCase() === 'pending').length;
    const unpaidInvoices = invoices.filter(invoice => Number(invoice.totalAmount || 0) > Number(invoice.paidAmount || 0)).length;

    return {
        pendingApprovals,
        pendingBargains,
        overdueReturns,
        dueSoonReturns,
        returnsToday,
        unpaidInvoices,
        riskScore: overdueReturns + unpaidInvoices + pendingBargains
    };
}

function getDashboardNotifications() {
    const notifications = [];
    const now = new Date();
    const bookingRequests = getBookingRequests();

    const pendingScannerRequests = bookingRequests
        .filter(request => String(request.source || '').toLowerCase() === 'scanner-pickup')
        .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    pendingScannerRequests.slice(0, 3).forEach(request => {
        notifications.push({
            level: 'info',
            createdAt: request.createdAt || new Date().toISOString(),
            text: `New scanner pickup request from ${request.customer || 'Customer'} for ${request.car || 'Vehicle'}.`,
            actionLabel: 'Review',
            actionKey: 'pending-approvals'
        });
    });

    const overdueRentals = rentals
        .filter(rental => (rental.status || 'active') === 'active')
        .filter(rental => new Date(rental.returnDate) < now)
        .sort((a, b) => new Date(a.returnDate) - new Date(b.returnDate));

    overdueRentals.slice(0, 2).forEach(rental => {
        notifications.push({
            level: 'warning',
            createdAt: rental.returnDate,
            text: `Overdue return: ${rental.customer || 'Customer'} (${rental.car || 'Vehicle'}).`,
            actionLabel: 'Open',
            actionKey: 'overdue-returns'
        });
    });

    const unpaidInvoice = invoices.find(invoice => Number(invoice.totalAmount || 0) > Number(invoice.paidAmount || 0));
    if (unpaidInvoice) {
        notifications.push({
            level: 'warning',
            createdAt: unpaidInvoice.updatedAt || unpaidInvoice.createdAt || new Date().toISOString(),
            text: `Unpaid invoice pending for ${unpaidInvoice.customer || 'Customer'} (${unpaidInvoice.invoiceNumber || 'No Ref'}).`,
            actionLabel: 'Inspect',
            actionKey: 'unpaid-invoices'
        });
    }

    if (!notifications.length) {
        notifications.push({
            level: 'ok',
            createdAt: new Date().toISOString(),
            text: 'No urgent notifications right now. Operations look stable.',
            actionLabel: '',
            actionKey: ''
        });
    }

    return notifications
        .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))
        .slice(0, 6);
}

function renderDashboardNotifications() {
    const list = document.getElementById('dashboard-notifications-list');
    const count = document.getElementById('notification-count');
    if (!list || !count) return;

    const notifications = getDashboardNotifications();
    const actionableCount = notifications.filter(item => item.actionKey).length;
    count.textContent = actionableCount;

    list.innerHTML = notifications.map(item => {
        const levelClass = item.level === 'warning' ? 'warning' : item.level === 'ok' ? 'ok' : 'info';
        const timestamp = new Date(item.createdAt || Date.now());

        return `
            <article class="dashboard-notice ${levelClass}">
                <div>
                    <p class="dashboard-notice-text">${item.text}</p>
                    <p class="dashboard-notice-time">${timestamp.toLocaleString()}</p>
                </div>
                ${item.actionKey ? `<button type="button" class="btn btn-secondary btn-compact" onclick="handleActionCenter('${item.actionKey}')">${item.actionLabel || 'Open'}</button>` : ''}
            </article>
        `;
    }).join('');
}

let editingCarId = null;

function initializeStatsCardFilters() {
    document.querySelectorAll('.stat-card[data-filter]').forEach(card => {
        card.addEventListener('click', () => {
            const filter = card.dataset.filter;
            if (!filter) return;
            applyFleetFilter(filter, { scrollToFleet: true });
        });
    });
}

// ===== INITIALIZE =====
document.addEventListener('DOMContentLoaded', async function() {
    await loadData();
    updateStats();
    renderFleet();
    renderBookingRequests();
    renderBargainOffers();
    renderRentals();
    renderRentedCarsDetails();
    renderServiceHistory();
    renderInvoiceCenter();
    populateCarSelect();
    initializeBookingDateInputs();
    initializeNavLinks();
    initializeStatsCardFilters();
    setActiveFleetFilterButton(activeFleetFilter);
    
    // Set up filter buttons
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            applyFleetFilter(this.dataset.filter);
        });
    });

    const fleetSearchInput = document.getElementById('fleet-search');
    if (fleetSearchInput) {
        fleetSearchInput.addEventListener('input', (event) => {
            fleetSearchQuery = (event.target.value || '').trim().toLowerCase();
            renderFleet();
        });
    }

    const fleetSortSelect = document.getElementById('fleet-sort');
    if (fleetSortSelect) {
        fleetSortSelect.addEventListener('change', (event) => {
            fleetSortMode = event.target.value || 'name-asc';
            renderFleet();
        });
    }

    const bookingSearchInput = document.getElementById('booking-search');
    if (bookingSearchInput) {
        bookingSearchInput.addEventListener('input', (event) => {
            bookingSearchQuery = (event.target.value || '').trim().toLowerCase();
            renderRentals();
        });
    }

    const bookingStatusSelect = document.getElementById('booking-status-filter');
    if (bookingStatusSelect) {
        bookingStatusSelect.addEventListener('change', (event) => {
            bookingStatusFilter = event.target.value || 'active';
            bookingQuickFilterMode = 'all';
            setActiveTrackerFilterButton('all');
            renderRentals();
        });
    }

    const bookingSortSelect = document.getElementById('booking-sort');
    if (bookingSortSelect) {
        bookingSortSelect.addEventListener('change', (event) => {
            bookingSortMode = event.target.value || 'recent';
            renderRentals();
        });
    }

    const requestSearchInput = document.getElementById('request-search');
    if (requestSearchInput) {
        requestSearchInput.addEventListener('input', (event) => {
            requestSearchQuery = (event.target.value || '').trim().toLowerCase();
            renderBookingRequests();
        });
    }

    const requestSortSelect = document.getElementById('request-sort');
    if (requestSortSelect) {
        requestSortSelect.addEventListener('change', (event) => {
            requestSortMode = event.target.value || 'newest';
            renderBookingRequests();
        });
    }

    document.querySelectorAll('.tracker-btn[data-track]').forEach(button => {
        button.addEventListener('click', () => {
            const mode = button.dataset.track || 'all';
            bookingQuickFilterMode = mode;
            setActiveTrackerFilterButton(mode);
            renderRentals();
        });
    });

    const revenueRangeSelect = document.getElementById('revenue-range');
    if (revenueRangeSelect) {
        revenueRangeSelect.addEventListener('change', (event) => {
            revenueRangeDays = Number(event.target.value) || 14;
            renderRevenueGraph();
        });
    }
    
    // Set up booking form
    document.getElementById('booking-form').addEventListener('submit', handleNewBooking);
    const addVehicleForm = document.getElementById('car-form');
    if (addVehicleForm) {
        addVehicleForm.addEventListener('submit', handleAddCar);
    }

    const editVehicleForm = document.getElementById('edit-car-form');
    if (editVehicleForm) {
        editVehicleForm.addEventListener('submit', handleEditCar);
    }

    const deleteVehicleButton = document.getElementById('edit-delete-car-btn');
    if (deleteVehicleButton) {
        deleteVehicleButton.addEventListener('click', () => {
            if (!editingCarId) return;
            deleteCar(editingCarId);
        });
    }

    const negotiationForm = document.getElementById('offer-negotiation-form');
    if (negotiationForm) {
        negotiationForm.addEventListener('submit', (event) => {
            event.preventDefault();
            sendNegotiationMessage();
        });
    }

    const counterButton = document.getElementById('offer-send-counter-btn');
    if (counterButton) {
        counterButton.addEventListener('click', () => sendCounterFromNegotiation());
    }

    const acceptButton = document.getElementById('offer-accept-btn');
    if (acceptButton) {
        acceptButton.addEventListener('click', () => {
            if (!activeNegotiationOfferId) return;
            acceptPriceOffer(activeNegotiationOfferId);
            openOfferNegotiation(activeNegotiationOfferId);
        });
    }

    const rejectButton = document.getElementById('offer-reject-btn');
    if (rejectButton) {
        rejectButton.addEventListener('click', () => {
            if (!activeNegotiationOfferId) return;
            rejectPriceOffer(activeNegotiationOfferId);
            openOfferNegotiation(activeNegotiationOfferId);
        });
    }

    renderRevenueAnalytics();
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
    const finance = getInvoiceFinanceSummary();
    
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

    const invoicedMonthEl = document.getElementById('invoiced-month');
    if (invoicedMonthEl) {
        invoicedMonthEl.textContent = `$${finance.invoicedThisMonth.toFixed(2)}`;
    }

    const unpaidTotalEl = document.getElementById('unpaid-total');
    if (unpaidTotalEl) {
        unpaidTotalEl.textContent = `$${finance.totalUnpaid.toFixed(2)}`;
    }

    const totalCarsEl = document.getElementById('overview-total-cars');
    if (totalCarsEl) {
        totalCarsEl.textContent = fleet.length;
    }

    const activeBookingsEl = document.getElementById('overview-active-bookings');
    if (activeBookingsEl) {
        activeBookingsEl.textContent = rentals.filter(rental => (rental.status || 'active') === 'active').length;
    }

    const insights = getOperationalInsights();
    const pendingOffersCount = insights.pendingBargains;
    const pendingBargainsEl = document.getElementById('overview-pending-bargains');
    if (pendingBargainsEl) {
        pendingBargainsEl.textContent = pendingOffersCount;
    }

    const trendText = document.getElementById('overview-trend-text');
    if (trendText) {
        trendText.classList.remove('positive', 'negative');
        const signal = insights.overdueReturns + insights.pendingApprovals;
        if (signal === 0) {
            trendText.textContent = 'Operations are healthy: no overdue returns and no pending approvals.';
            trendText.classList.add('positive');
        } else {
            trendText.textContent = `Attention needed: ${insights.overdueReturns} overdue return(s), ${insights.pendingApprovals} pending approval(s), ${insights.pendingBargains} pending bargain(s).`;
            trendText.classList.add('negative');
        }
    }

    const actionPendingApprovalsEl = document.getElementById('action-pending-approvals');
    if (actionPendingApprovalsEl) {
        actionPendingApprovalsEl.textContent = insights.pendingApprovals;
    }

    const actionPendingBargainsEl = document.getElementById('action-pending-bargains');
    if (actionPendingBargainsEl) {
        actionPendingBargainsEl.textContent = insights.pendingBargains;
    }

    const actionOverdueReturnsEl = document.getElementById('action-overdue-returns');
    if (actionOverdueReturnsEl) {
        actionOverdueReturnsEl.textContent = insights.overdueReturns;
    }

    const actionUnpaidInvoicesEl = document.getElementById('action-unpaid-invoices');
    if (actionUnpaidInvoicesEl) {
        actionUnpaidInvoicesEl.textContent = insights.unpaidInvoices;
    }

    const actionRiskEl = document.getElementById('action-center-risk');
    if (actionRiskEl) {
        actionRiskEl.textContent = `Risk: ${insights.riskScore}`;
    }

    const managerPending = document.getElementById('bm-pending');
    if (managerPending) managerPending.textContent = insights.pendingApprovals;

    const managerActive = document.getElementById('bm-active');
    if (managerActive) managerActive.textContent = rentals.filter(rental => (rental.status || 'active') === 'active').length;

    const managerOverdue = document.getElementById('bm-overdue');
    if (managerOverdue) managerOverdue.textContent = insights.overdueReturns;

    const managerDueSoon = document.getElementById('bm-due-soon');
    if (managerDueSoon) managerDueSoon.textContent = insights.dueSoonReturns;

    const managerHealth = document.getElementById('booking-manager-health');
    if (managerHealth) {
        managerHealth.textContent = insights.overdueReturns > 0 ? 'Attention Needed' : 'On Track';
    }

    const updatedEl = document.getElementById('overview-last-updated');
    if (updatedEl) {
        updatedEl.textContent = `Updated ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
    }

    renderDashboardNotifications();

    renderRevenueGraph();
    renderRevenueAnalytics();
}

function setActiveTrackerFilterButton(mode = 'all') {
    document.querySelectorAll('.tracker-btn[data-track]').forEach(button => {
        button.classList.toggle('active', button.dataset.track === mode);
    });
}

function formatChartLabel(date) {
    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function getRevenueSeries(days = 14) {
    const targetDays = Math.max(1, Number(days) || 14);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const series = [];
    for (let offset = targetDays - 1; offset >= 0; offset -= 1) {
        const day = new Date(today);
        day.setDate(today.getDate() - offset);
        series.push({
            date: day,
            key: day.toISOString().slice(0, 10),
            value: 0
        });
    }

    const indexByKey = new Map(series.map((point, index) => [point.key, index]));

    if (Array.isArray(invoices) && invoices.length > 0) {
        invoices.forEach(invoice => {
            const issueDate = new Date(invoice.issueDate || invoice.createdAt || 0);
            if (Number.isNaN(issueDate.getTime())) return;

            const key = issueDate.toISOString().slice(0, 10);
            if (!indexByKey.has(key)) return;

            const amount = Number(invoice.totalAmount || 0);
            series[indexByKey.get(key)].value += Number.isFinite(amount) ? amount : 0;
        });
        return series;
    }

    rentals.forEach(rental => {
        const referenceDate = getBookingReferenceDate(rental);
        if (Number.isNaN(referenceDate.getTime())) return;

        const key = referenceDate.toISOString().slice(0, 10);
        if (!indexByKey.has(key)) return;

        const car = fleet.find(item => Number(item.id) === Number(rental.carId));
        const amount = calculateRentalAmount(rental, car).totalAmount;
        series[indexByKey.get(key)].value += Number.isFinite(amount) ? amount : 0;
    });

    return series;
}

function getRevenueTotalForDaysEnding(dayEndDate, days) {
    const targetDays = Math.max(1, Number(days) || 14);
    const end = new Date(dayEndDate);
    end.setHours(23, 59, 59, 999);
    const start = new Date(end);
    start.setDate(end.getDate() - (targetDays - 1));
    start.setHours(0, 0, 0, 0);

    const inRange = (dateValue) => {
        const date = new Date(dateValue);
        return !Number.isNaN(date.getTime()) && date >= start && date <= end;
    };

    if (Array.isArray(invoices) && invoices.length > 0) {
        return invoices.reduce((sum, invoice) => {
            if (!inRange(invoice.issueDate || invoice.createdAt)) return sum;
            const amount = Number(invoice.totalAmount || 0);
            return sum + (Number.isFinite(amount) ? amount : 0);
        }, 0);
    }

    return rentals.reduce((sum, rental) => {
        if (!inRange(rental.createdAt || rental.pickupDate)) return sum;
        const car = fleet.find(item => Number(item.id) === Number(rental.carId));
        return sum + calculateRentalAmount(rental, car).totalAmount;
    }, 0);
}

function renderRevenueGraph() {
    const chart = document.getElementById('revenue-chart');
    const startLabel = document.getElementById('chart-start-label');
    const endLabel = document.getElementById('chart-end-label');
    const summary = document.getElementById('revenue-chart-summary');
    if (!chart || !startLabel || !endLabel || !summary) return;

    const series = getRevenueSeries(revenueRangeDays);
    const maxValue = Math.max(...series.map(item => item.value), 0);
    const normalizedMax = maxValue > 0 ? maxValue : 1;

    const width = 760;
    const height = 240;
    const leftPadding = 24;
    const rightPadding = 18;
    const topPadding = 16;
    const bottomPadding = 28;
    const graphWidth = width - leftPadding - rightPadding;
    const graphHeight = height - topPadding - bottomPadding;
    const step = series.length > 1 ? graphWidth / (series.length - 1) : graphWidth;

    const points = series.map((item, index) => {
        const x = leftPadding + step * index;
        const ratio = item.value / normalizedMax;
        const y = topPadding + graphHeight - (ratio * graphHeight);
        return { x, y, ...item };
    });

    const pathLine = points.map((point, index) => `${index === 0 ? 'M' : 'L'} ${point.x} ${point.y}`).join(' ');
    const areaPath = `${pathLine} L ${leftPadding + graphWidth} ${topPadding + graphHeight} L ${leftPadding} ${topPadding + graphHeight} Z`;

    const guideLines = [0.25, 0.5, 0.75, 1].map(level => {
        const y = topPadding + graphHeight - (level * graphHeight);
        return `<line x1="${leftPadding}" y1="${y}" x2="${leftPadding + graphWidth}" y2="${y}" stroke="#e5edf8" stroke-width="1" />`;
    }).join('');

    const circles = points.map(point => `
        <circle cx="${point.x}" cy="${point.y}" r="3.2" fill="#2563eb">
            <title>${formatChartLabel(point.date)} — $${point.value.toFixed(2)}</title>
        </circle>
    `).join('');

    chart.innerHTML = `
        <defs>
            <linearGradient id="revenueAreaGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#3b82f6" stop-opacity="0.24"></stop>
                <stop offset="100%" stop-color="#3b82f6" stop-opacity="0.03"></stop>
            </linearGradient>
        </defs>
        ${guideLines}
        <path d="${areaPath}" fill="url(#revenueAreaGradient)"></path>
        <path d="${pathLine}" fill="none" stroke="#2563eb" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"></path>
        ${circles}
    `;

    startLabel.textContent = formatChartLabel(series[0].date);
    endLabel.textContent = formatChartLabel(series[series.length - 1].date);

    const totalRevenue = series.reduce((sum, point) => sum + point.value, 0);
    summary.textContent = `Revenue total for last ${revenueRangeDays} day(s): $${totalRevenue.toFixed(2)}.`;

    const deltaEl = document.getElementById('revenue-chart-delta');
    if (deltaEl) {
        const currentPeriodEnd = new Date();
        currentPeriodEnd.setHours(23, 59, 59, 999);
        const previousPeriodEnd = new Date(currentPeriodEnd);
        previousPeriodEnd.setDate(currentPeriodEnd.getDate() - revenueRangeDays);

        const previousTotal = getRevenueTotalForDaysEnding(previousPeriodEnd, revenueRangeDays);
        const delta = totalRevenue - previousTotal;
        const deltaPercent = previousTotal > 0 ? (delta / previousTotal) * 100 : (totalRevenue > 0 ? 100 : 0);

        deltaEl.classList.remove('positive', 'negative');
        if (delta >= 0) {
            deltaEl.classList.add('positive');
            deltaEl.textContent = `Up ${deltaPercent.toFixed(1)}% (+$${delta.toFixed(2)}) vs previous ${revenueRangeDays}-day period.`;
        } else {
            deltaEl.classList.add('negative');
            deltaEl.textContent = `Down ${Math.abs(deltaPercent).toFixed(1)}% (-$${Math.abs(delta).toFixed(2)}) vs previous ${revenueRangeDays}-day period.`;
        }
    }
}

function renderRevenueAnalytics() {
    const dailyEl = document.getElementById('earnings-daily');
    const weeklyEl = document.getElementById('earnings-weekly');
    const monthlyEl = document.getElementById('earnings-monthly');
    const performanceCountEl = document.getElementById('car-performance-count');
    const performanceListEl = document.getElementById('car-performance-list');
    const badgeEl = document.getElementById('revenue-analytics-badge');

    if (!dailyEl || !weeklyEl || !monthlyEl || !performanceCountEl || !performanceListEl) return;

    const today = new Date();
    today.setHours(23, 59, 59, 999);
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

    const dailyRevenue = getRevenueTotalForDaysEnding(today, 1);
    const weeklyRevenue = getRevenueTotalForDaysEnding(today, 7);

    const revenueForMonth = (Array.isArray(invoices) && invoices.length > 0)
        ? invoices.reduce((sum, invoice) => {
            const issueDate = new Date(invoice.issueDate || invoice.createdAt || 0);
            if (Number.isNaN(issueDate.getTime()) || issueDate < monthStart) return sum;
            const amount = Number(invoice.totalAmount || 0);
            return sum + (Number.isFinite(amount) ? amount : 0);
        }, 0)
        : rentals.reduce((sum, rental) => {
            const referenceDate = getBookingReferenceDate(rental);
            if (Number.isNaN(referenceDate.getTime()) || referenceDate < monthStart) return sum;
            const car = fleet.find(item => Number(item.id) === Number(rental.carId));
            return sum + calculateRentalAmount(rental, car).totalAmount;
        }, 0);

    dailyEl.textContent = `$${dailyRevenue.toFixed(2)}`;
    weeklyEl.textContent = `$${weeklyRevenue.toFixed(2)}`;
    monthlyEl.textContent = `$${revenueForMonth.toFixed(2)}`;

    if (badgeEl) {
        badgeEl.textContent = `Updated ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
    }

    const carPerformance = fleet.map(car => {
        const carRentals = rentals.filter(rental => Number(rental.carId) === Number(car.id));
        const completed = carRentals.filter(rental => (rental.status || '').toLowerCase() === 'completed').length;
        const active = carRentals.filter(rental => (rental.status || '').toLowerCase() === 'active').length;
        const revenue = carRentals.reduce((sum, rental) => {
            return sum + calculateRentalAmount(rental, car).totalAmount;
        }, 0);

        return {
            carName: car.name || car.model || 'Vehicle',
            license: car.license || car.rego || 'N/A',
            bookings: carRentals.length,
            completed,
            active,
            revenue
        };
    }).sort((first, second) => second.revenue - first.revenue);

    performanceCountEl.textContent = carPerformance.length;

    if (carPerformance.length === 0) {
        performanceListEl.innerHTML = '<p style="color:#6b7280; margin:0;">No vehicle performance data yet.</p>';
        return;
    }

    const rows = carPerformance.slice(0, 10).map(item => `
        <div class="performance-row">
            <span><strong>${item.carName}</strong><br><small style="color:#64748b;">${item.license}</small></span>
            <span>${item.bookings}</span>
            <span>${item.active}</span>
            <span>$${item.revenue.toFixed(2)}</span>
        </div>
    `).join('');

    performanceListEl.innerHTML = `
        <div class="performance-row header">
            <span>Vehicle</span>
            <span>Bookings</span>
            <span>Active</span>
            <span>Revenue</span>
        </div>
        ${rows}
    `;
}

function handleActionCenter(actionKey) {
    if (!actionKey) return;

    if (actionKey === 'pending-approvals') {
        showTabSection('bookings');
        bookingStatusFilter = 'all';
        bookingQuickFilterMode = 'all';
        const statusSelect = document.getElementById('booking-status-filter');
        if (statusSelect) statusSelect.value = 'all';
        renderBookingRequests();
        renderRentals();
        const section = document.getElementById('booking-requests-section');
        if (section) section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        return;
    }

    if (actionKey === 'pending-bargains') {
        showTabSection('bookings');
        renderBargainOffers();
        const section = document.getElementById('bargain-offers-section');
        if (section) section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        return;
    }

    if (actionKey === 'overdue-returns') {
        showTabSection('bookings');
        bookingStatusFilter = 'active';
        bookingQuickFilterMode = 'overdue';
        const statusSelect = document.getElementById('booking-status-filter');
        if (statusSelect) statusSelect.value = 'active';
        renderRentals();
        return;
    }

    if (actionKey === 'unpaid-invoices') {
        showTabSection('reports');
        renderInvoiceCenter();
        const section = document.getElementById('invoice-center');
        if (section) section.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

function hasMeaningfulValue(value) {
    if (value === null || value === undefined) return false;
    const text = String(value).trim().toLowerCase();
    return text !== '' && text !== 'n/a' && text !== 'na' && text !== 'unknown' && text !== '-';
}

function getBookingReferenceDate(rental) {
    const reference = rental?.createdAt || rental?.pickupDate;
    const parsedDate = new Date(reference);
    if (Number.isNaN(parsedDate.getTime())) {
        return new Date(0);
    }
    return parsedDate;
}

function getInvoiceFinanceSummary() {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    return invoices.reduce((summary, invoice) => {
        const issuedOn = new Date(invoice.issueDate || invoice.createdAt || 0);
        const totalAmount = Number(invoice.totalAmount || 0);
        const paidAmount = Number(invoice.paidAmount || 0);
        const unpaidAmount = Math.max(0, totalAmount - paidAmount);

        if (!Number.isNaN(issuedOn.getTime()) && issuedOn >= monthStart) {
            summary.invoicedThisMonth += totalAmount;
        }

        summary.totalUnpaid += unpaidAmount;
        return summary;
    }, { invoicedThisMonth: 0, totalUnpaid: 0 });
}

function calculateRentalAmount(rental, car) {
    const pickupDate = new Date(rental.pickupDate);
    const returnDate = new Date(rental.returnDate);
    const totalDays = Math.max(1, Math.ceil((returnDate - pickupDate) / (1000 * 60 * 60 * 24)));
    const dailyRate = Number(car?.rate || 0);
    const subTotal = totalDays * dailyRate;
    const taxRate = 0.13;
    const taxAmount = subTotal * taxRate;
    const totalAmount = subTotal + taxAmount;

    return {
        pickupDate,
        returnDate,
        totalDays,
        dailyRate,
        subTotal,
        taxRate,
        taxAmount,
        totalAmount
    };
}

function getRentalInvoice(rentalId) {
    return invoices.find(invoice => Number(invoice.rentalId) === Number(rentalId));
}

function generateInvoiceFromRental(rentalId) {
    const rental = rentals.find(item => Number(item.id) === Number(rentalId));
    if (!rental) {
        showToast('Rental not found for invoice generation.', 'warning');
        return null;
    }

    const existingInvoice = getRentalInvoice(rentalId);
    if (existingInvoice) {
        return existingInvoice;
    }

    const car = fleet.find(item => Number(item.id) === Number(rental.carId));
    const amount = calculateRentalAmount(rental, car);
    const sequenceNumber = String(invoices.length + 1).padStart(5, '0');
    const issueDate = new Date().toISOString();

    const newInvoice = {
        id: Date.now(),
        invoiceNumber: `INV-${new Date().getFullYear()}-${sequenceNumber}`,
        rentalId: rental.id,
        customer: rental.customer || 'Customer',
        customerPhone: rental.phone || 'N/A',
        customerEmail: rental.email || 'N/A',
        carId: rental.carId,
        carName: rental.car || car?.name || 'Vehicle',
        status: rental.status === 'completed' ? 'closed' : 'open',
        issueDate,
        dueDate: rental.returnDate ? new Date(rental.returnDate).toISOString() : issueDate,
        pickupDate: amount.pickupDate.toISOString(),
        returnDate: amount.returnDate.toISOString(),
        totalDays: amount.totalDays,
        dailyRate: amount.dailyRate,
        subTotal: amount.subTotal,
        taxRate: amount.taxRate,
        taxAmount: amount.taxAmount,
        totalAmount: amount.totalAmount,
        paidAmount: 0,
        notes: rental.notes || '',
        createdAt: issueDate,
        updatedAt: issueDate
    };

    invoices.unshift(newInvoice);
    saveData();
    updateStats();
    renderInvoiceCenter();

    return newInvoice;
}

function syncInvoiceWithRentalStatus(rental) {
    const invoice = getRentalInvoice(rental.id);
    if (!invoice) return;

    invoice.status = rental.status === 'completed' ? 'closed' : 'open';
    invoice.updatedAt = new Date().toISOString();
    saveData();
}

// ===== RENDER FLEET =====
function renderFleet() {
    const grid = document.getElementById('fleet-grid');
    const statusFiltered = activeFleetFilter === 'all'
        ? [...fleet]
        : fleet.filter(car => car.status === activeFleetFilter);

    const searchedFleet = statusFiltered.filter(car => {
        if (!fleetSearchQuery) return true;
        const searchableText = [
            car.name,
            car.make,
            car.model,
            car.license,
            car.rego,
            car.color,
            car.status
        ].filter(hasMeaningfulValue).join(' ').toLowerCase();
        return searchableText.includes(fleetSearchQuery);
    });

    const filtered = searchedFleet.sort((firstCar, secondCar) => {
        if (fleetSortMode === 'rate-high') {
            return Number(secondCar.rate || 0) - Number(firstCar.rate || 0);
        }
        if (fleetSortMode === 'rate-low') {
            return Number(firstCar.rate || 0) - Number(secondCar.rate || 0);
        }
        if (fleetSortMode === 'status') {
            const firstStatus = (firstCar.status || '').toString();
            const secondStatus = (secondCar.status || '').toString();
            return firstStatus.localeCompare(secondStatus);
        }
        const firstName = (firstCar.name || firstCar.model || '').toString();
        const secondName = (secondCar.name || secondCar.model || '').toString();
        return firstName.localeCompare(secondName);
    });

    if (filtered.length === 0) {
        grid.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No vehicles match this filter.</p>';
        return;
    }
    
    grid.innerHTML = filtered.map(car => {
        const makeModel = [car.make, car.model].filter(hasMeaningfulValue).join(' ');
        const statusText = hasMeaningfulValue(car.status) ? car.status : 'available';
        const primaryName = hasMeaningfulValue(car.name) ? car.name : makeModel || `Vehicle ${car.id}`;
        const carModelText = hasMeaningfulValue(makeModel) ? makeModel : (hasMeaningfulValue(car.model) ? car.model : 'Vehicle');
        const coverImage = Array.isArray(car.images) && car.images.length ? car.images[0] : '';
        const priceDay = normalizeCarRate(car.priceDay ?? car.rate);
        const priceWeek = Number.isFinite(Number(car.priceWeek)) && Number(car.priceWeek) > 0
            ? Number(car.priceWeek)
            : Number((priceDay * 6).toFixed(2));
        const locationText = hasMeaningfulValue(car.location) ? car.location : 'Main Branch';
        const availabilityText = getAvailabilitySummary(car);

        const topDetails = [];
        const plateValue = hasMeaningfulValue(car.license) ? car.license : car.rego;
        if (hasMeaningfulValue(plateValue)) {
            topDetails.push(`🚗 ${plateValue}`);
        }
        if (hasMeaningfulValue(car.color)) {
            topDetails.push(`🎨 ${car.color}`);
        }
        topDetails.push(`📍 ${locationText}`);

        const secondaryDetails = [];
        if (Number.isFinite(Number(car.mileage)) && Number(car.mileage) > 0) {
            secondaryDetails.push(`📊 ${Number(car.mileage).toLocaleString()} km`);
        }
        if (hasMeaningfulValue(car.fuel) && String(car.fuel).toLowerCase() !== 'full') {
            secondaryDetails.push(`⛽ ${car.fuel}`);
        }
        secondaryDetails.push(`🗓️ ${availabilityText}`);

        const isRented = statusText === 'rented';

        return `
        <div class="fleet-card" data-id="${car.id}" ${isRented ? `onclick="openRentedCarDetails(${car.id})" style="cursor: pointer;"` : ''}>
            <div class="fleet-media-wrap">
                ${coverImage ? `<img src="${coverImage}" alt="${primaryName}" class="fleet-media">` : `<div class="fleet-media-placeholder">No Image</div>`}
            </div>
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
            <div class="car-pricing-row">
                <span>💵 $${priceDay.toFixed(2)}/day</span>
                <span>🗓️ $${priceWeek.toFixed(2)}/week</span>
            </div>
            ${secondaryDetails.length ? `<div class="car-details">${secondaryDetails.map(detail => `<span>${detail}</span>`).join('')}</div>` : ''}
            <div class="car-actions">
                <button class="btn-small btn-qr" onclick="event.stopPropagation(); generateCarQR(${car.id})">
                    📱 Generate QR
                </button>
                <button class="btn-small btn-edit" onclick="event.stopPropagation(); editCar(${car.id})">
                    ✏️ Edit
                </button>
                <button class="btn-small btn-edit" onclick="event.stopPropagation(); deleteCar(${car.id})">
                    🗑️ Delete
                </button>
                ${isRented ? `<button class="btn-small btn-primary" onclick="event.stopPropagation(); openRentedCarDetails(${car.id});">📋 Details</button>` : ''}
            </div>
        </div>
    `;
    }).join('');
}

function filterFleet(filter) {
    activeFleetFilter = filter || 'all';
    renderFleet();
}

// ===== RENDER RENTALS =====
function renderRentals() {
    const list = document.getElementById('rentals-list');
    const statusFilteredRentals = rentals.filter(rental => {
        if (bookingStatusFilter === 'all') return true;
        return (rental.status || 'active') === bookingStatusFilter;
    });

    const searchedRentals = statusFilteredRentals.filter(rental => {
        if (!bookingSearchQuery) return true;
        const linkedCar = fleet.find(car => Number(car.id) === Number(rental.carId));
        const searchableText = [
            rental.customer,
            rental.phone,
            rental.car,
            rental.email,
            rental.status,
            linkedCar?.license,
            linkedCar?.rego,
            linkedCar?.plateNumber,
            linkedCar?.plate
        ].filter(hasMeaningfulValue).join(' ').toLowerCase();
        return searchableText.includes(bookingSearchQuery);
    });

    const quickFilteredRentals = searchedRentals.filter(rental => {
        if (bookingQuickFilterMode === 'all') return true;
        const now = new Date();
        const returnDate = new Date(rental.returnDate);
        const hoursUntilReturn = (returnDate - now) / (1000 * 60 * 60);
        if (bookingQuickFilterMode === 'overdue') {
            return returnDate < now;
        }
        if (bookingQuickFilterMode === 'due-soon') {
            return returnDate >= now && hoursUntilReturn <= 24;
        }
        if (bookingQuickFilterMode === 'return-today') {
            return isSameCalendarDate(returnDate, now);
        }
        return true;
    });

    const sortedRentals = [...quickFilteredRentals].sort((firstRental, secondRental) => {
        if (bookingSortMode === 'return-soon') {
            return new Date(firstRental.returnDate) - new Date(secondRental.returnDate);
        }
        if (bookingSortMode === 'customer-asc') {
            return String(firstRental.customer || '').localeCompare(String(secondRental.customer || ''));
        }
        return getBookingReferenceDate(secondRental) - getBookingReferenceDate(firstRental);
    });

    document.getElementById('active-rental-count').textContent = sortedRentals.length;

    if (sortedRentals.length === 0) {
        list.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No bookings match this filter.</p>';
        return;
    }

    list.innerHTML = sortedRentals.map(rental => {
        const now = new Date();
        const timeUntilReturn = rental.returnDate - now;
        const hoursUntil = Math.floor(timeUntilReturn / (1000 * 60 * 60));
        const isOverdue = timeUntilReturn < 0;
        const status = hasMeaningfulValue(rental.status) ? rental.status : 'active';
        const isActive = status === 'active';
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
        if (!isActive) {
            dueText = `<span>${status.charAt(0).toUpperCase() + status.slice(1)}</span>`;
        } else if (isOverdue) {
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
                    <span class="status-badge status-${status}" style="align-self: center;">${status.charAt(0).toUpperCase() + status.slice(1)}</span>
                    <div class="due-time">
                        <strong>${isActive ? 'Return Time' : 'Booking Date'}</strong>
                        ${dueText}
                    </div>
                    <button class="btn-small btn-primary" onclick="showRentalDetails(${rental.id})">
                        View Details
                    </button>
                    <button class="btn-small btn-edit" onclick="showRentalCustomerProfile(${rental.id})">
                        👤 Customer
                    </button>
                    <button class="btn-small btn-qr" onclick="openInvoiceForRental(${rental.id})">
                        🧾 Invoice
                    </button>
                    ${isActive ? `
                        <button class="btn-small btn-edit" onclick="completeRental(${rental.id})">
                            ✅ Complete
                        </button>
                    ` : ''}
                </div>
            </div>
        `;
    }).join('');
}

function renderRentedCarsDetails() {
    const container = document.getElementById('rented-cars-list');
    const countBadge = document.getElementById('rented-cars-count');
    if (!container || !countBadge) return;

    const activeRentals = rentals
        .filter(rental => rental.status === 'active')
        .sort((a, b) => new Date(b.pickupDate) - new Date(a.pickupDate));

    countBadge.textContent = activeRentals.length;

    if (activeRentals.length === 0) {
        container.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No rented cars to show</p>';
        return;
    }

    container.innerHTML = activeRentals.map(rental => {
        const car = fleet.find(item => item.id === rental.carId) || {};
        const customerName = hasMeaningfulValue(rental.customer) ? rental.customer : 'Customer';
        const customerPhone = hasMeaningfulValue(rental.phone) ? rental.phone : 'N/A';
        const customerEmail = hasMeaningfulValue(rental.email) ? rental.email : 'N/A';

        const carName = hasMeaningfulValue(rental.car) ? rental.car : (hasMeaningfulValue(car.name) ? car.name : 'Assigned Vehicle');
        const plate = hasMeaningfulValue(car.license) ? car.license : (hasMeaningfulValue(car.rego) ? car.rego : 'N/A');
        const status = hasMeaningfulValue(car.status) ? car.status : 'rented';
        const rate = Number.isFinite(Number(car.rate)) ? Number(car.rate) : 0;

        const pickupDate = new Date(rental.pickupDate);
        const returnDate = new Date(rental.returnDate);
        const totalDays = Math.max(1, Math.ceil((returnDate - pickupDate) / (1000 * 60 * 60 * 24)));
        const totalCost = rate > 0 ? rate * totalDays : 0;

        return `
            <div style="background: white; border: 1px solid #e5e7eb; border-radius: 12px; padding: 1rem 1.25rem; box-shadow: 0 2px 8px rgba(0,0,0,0.04);">
                <div style="display:flex; justify-content:space-between; align-items:flex-start; gap:1rem; flex-wrap:wrap;">
                    <div>
                        <h4 style="margin:0 0 0.35rem 0; color:#111827;">${carName}</h4>
                        <p style="margin:0; color:#6b7280; font-size:0.9rem;">🚗 Plate: ${plate} • Status: ${status}</p>
                    </div>
                    <div style="text-align:right;">
                        <p style="margin:0; font-weight:600; color:#111827;">$${totalCost.toFixed(2)}</p>
                        <p style="margin:0; color:#6b7280; font-size:0.85rem;">$${rate.toFixed(2)}/day • ${totalDays} day(s)</p>
                    </div>
                </div>
                <div style="margin-top:0.75rem; display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:0.5rem 1rem;">
                    <p style="margin:0; color:#374151;"><strong>Customer:</strong> ${customerName}</p>
                    <p style="margin:0; color:#374151;"><strong>Phone:</strong> ${customerPhone}</p>
                    <p style="margin:0; color:#374151;"><strong>Email:</strong> ${customerEmail}</p>
                    <p style="margin:0; color:#374151;"><strong>Pickup:</strong> ${pickupDate.toLocaleString()}</p>
                    <p style="margin:0; color:#374151;"><strong>Return:</strong> ${returnDate.toLocaleString()}</p>
                </div>
                <div style="display:flex; gap:0.5rem; margin-top:0.85rem; flex-wrap:wrap;">
                    <button class="btn-small btn-primary" onclick="showRentalDetails(${Number(rental.id)})">📋 Full Details</button>
                    <button class="btn-small btn-qr" onclick="openInvoiceForRental(${Number(rental.id)})">🧾 Invoice</button>
                </div>
            </div>
        `;
    }).join('');
}

function renderBookingRequests() {
    const list = document.getElementById('booking-requests-list');
    const count = document.getElementById('booking-requests-count');
    if (!list || !count) return;

    const requests = getBookingRequests().filter(request => String(request.status || 'pending').toLowerCase() === 'pending');

    const searchedRequests = requests.filter(request => {
        if (!requestSearchQuery) return true;
        const linkedCar = fleet.find(car => Number(car.id) === Number(request.carId));
        const searchable = [
            request.customer,
            request.phone,
            request.email,
            request.car,
            request.notes,
            linkedCar?.license,
            linkedCar?.rego,
            linkedCar?.plateNumber,
            linkedCar?.plate
        ].filter(hasMeaningfulValue).join(' ').toLowerCase();
        return searchable.includes(requestSearchQuery);
    });

    const sortedRequests = [...searchedRequests].sort((a, b) => {
        if (requestSortMode === 'pickup-soon') {
            return new Date(a.pickupDate) - new Date(b.pickupDate);
        }
        if (requestSortMode === 'customer') {
            return String(a.customer || '').localeCompare(String(b.customer || ''));
        }
        return new Date(b.createdAt || 0) - new Date(a.createdAt || 0);
    });

    count.textContent = sortedRequests.length;

    if (sortedRequests.length === 0) {
        list.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No pending booking requests</p>';
        return;
    }

    list.innerHTML = sortedRequests.map(request => {
        const requestedCar = fleet.find(car => car.id === Number(request.carId));
        const carName = request.car || requestedCar?.name || 'Requested Vehicle';
        const plate = requestedCar?.license || requestedCar?.rego || 'N/A';
        const createdAt = new Date(request.createdAt || Date.now());
        const pickup = new Date(request.pickupDate);
        const dropoff = new Date(request.returnDate);
        const statusHint = requestedCar?.status === 'available' ? '✅ Available' : '⚠️ Currently unavailable';
        const sourceLabel = String(request.source || 'customer-portal') === 'scanner-pickup' ? 'Scanner Pickup' : 'Customer Portal';

        return `
            <div style="background:white; border:1px solid #e5e7eb; border-radius:12px; padding:1rem 1.25rem; box-shadow:0 2px 8px rgba(0,0,0,0.04);">
                <div style="display:flex; justify-content:space-between; gap:1rem; flex-wrap:wrap; align-items:flex-start;">
                    <div>
                        <h4 style="margin:0 0 0.35rem 0; color:#111827;">${request.customer || 'Customer'} — ${carName}</h4>
                        <p style="margin:0; color:#6b7280; font-size:0.9rem;">📅 Requested: ${createdAt.toLocaleString()} • ${statusHint} • ${sourceLabel}</p>
                    </div>
                    <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
                        <button class="btn-small btn-edit" onclick="showRequestCustomerProfile(${Number(request.id)})">👤 Customer</button>
                        <button class="btn-small btn-primary" onclick="approveBookingRequest(${Number(request.id)})">✅ Approve</button>
                        <button class="btn-small btn-edit" onclick="rejectBookingRequest(${Number(request.id)})">❌ Reject</button>
                    </div>
                </div>
                <div style="margin-top:0.75rem; display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:0.5rem 1rem;">
                    <p style="margin:0; color:#374151;"><strong>Phone:</strong> ${request.phone || 'N/A'}</p>
                    <p style="margin:0; color:#374151;"><strong>Email:</strong> ${request.email || 'N/A'}</p>
                    <p style="margin:0; color:#374151;"><strong>Plate:</strong> ${plate}</p>
                    <p style="margin:0; color:#374151;"><strong>Pickup:</strong> ${pickup.toLocaleString()}</p>
                    <p style="margin:0; color:#374151;"><strong>Return:</strong> ${dropoff.toLocaleString()}</p>
                    ${request.notes ? `<p style="margin:0; color:#374151;"><strong>Notes:</strong> ${request.notes}</p>` : ''}
                </div>
            </div>
        `;
    }).join('');
}

function showRequestCustomerProfile(requestId) {
    const request = getBookingRequests().find(item => Number(item.id) === Number(requestId));
    if (!request) {
        showToast('Customer profile not found for this request.', 'warning');
        return;
    }

    const content = document.getElementById('customer-profile-content');
    if (!content) return;

    const createdAt = new Date(request.createdAt || Date.now());
    content.innerHTML = `
        <div style="background:#f9fafb; border:1px solid #e5e7eb; border-radius:10px; padding:0.9rem 1rem;">
            <h3 style="margin:0 0 0.35rem 0; color:#111827;">${request.customer || 'Customer'}</h3>
            <p style="margin:0; color:#6b7280;">Request #${request.id} • ${createdAt.toLocaleString()}</p>
        </div>
        <div style="display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:0.65rem;">
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Contact</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">📞 ${request.phone || 'N/A'}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">✉️ ${request.email || 'N/A'}</p>
            </div>
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Requested Booking</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">🚗 ${request.car || 'Vehicle'}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Pickup: ${new Date(request.pickupDate).toLocaleString()}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Return: ${new Date(request.returnDate).toLocaleString()}</p>
            </div>
        </div>
        ${request.notes ? `<div style="background:#fff7ed; border:1px solid #fed7aa; border-radius:10px; padding:0.85rem;"><strong>Notes:</strong> ${request.notes}</div>` : ''}
    `;

    showModal('customer-profile-modal');
}

function showRentalCustomerProfile(rentalId) {
    const rental = rentals.find(item => Number(item.id) === Number(rentalId));
    if (!rental) {
        showToast('Customer profile not found for this rental.', 'warning');
        return;
    }

    const content = document.getElementById('customer-profile-content');
    if (!content) return;

    const bookingDate = getBookingReferenceDate(rental);
    content.innerHTML = `
        <div style="background:#f9fafb; border:1px solid #e5e7eb; border-radius:10px; padding:0.9rem 1rem;">
            <h3 style="margin:0 0 0.35rem 0; color:#111827;">${rental.customer || 'Customer'}</h3>
            <p style="margin:0; color:#6b7280;">Rental #${rental.id} • ${bookingDate.toLocaleString()}</p>
        </div>
        <div style="display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:0.65rem;">
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Contact</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">📞 ${rental.phone || 'N/A'}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">✉️ ${rental.email || 'N/A'}</p>
            </div>
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Active Rental</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">🚗 ${rental.car || 'Vehicle'}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Pickup: ${new Date(rental.pickupDate).toLocaleString()}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Return: ${new Date(rental.returnDate).toLocaleString()}</p>
            </div>
        </div>
        ${rental.notes ? `<div style="background:#fff7ed; border:1px solid #fed7aa; border-radius:10px; padding:0.85rem;"><strong>Notes:</strong> ${rental.notes}</div>` : ''}
    `;

    showModal('customer-profile-modal');
}

function renderBargainOffers() {
    const list = document.getElementById('bargain-offers-list');
    const count = document.getElementById('bargain-offers-count');
    if (!list || !count) return;

    const offers = getPriceOffers()
        .map(ensureOfferConversation)
        .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    savePriceOffers(offers);

    count.textContent = offers.length;

    if (!offers.length) {
        list.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No bargain offers yet</p>';
        return;
    }

    list.innerHTML = offers.map(offer => {
        const status = hasMeaningfulValue(offer.status) ? String(offer.status).toLowerCase() : 'pending';
        const listedRate = Number(offer.listedRate || 0);
        const offeredRate = Number(offer.offeredRate || 0);
        const statusClass = status === 'accepted' ? 'status-available' : status === 'rejected' ? 'status-rented' : 'status-maintenance';
        const createdDate = new Date(offer.createdAt || Date.now());
        const lastMessage = Array.isArray(offer.negotiationMessages) && offer.negotiationMessages.length
            ? offer.negotiationMessages[offer.negotiationMessages.length - 1]
            : null;

        return `
            <div style="background:white; border:1px solid #e5e7eb; border-radius:12px; padding:1rem 1.25rem; box-shadow:0 2px 8px rgba(0,0,0,0.04);">
                <div style="display:flex; justify-content:space-between; gap:1rem; flex-wrap:wrap; align-items:flex-start;">
                    <div>
                        <h4 style="margin:0 0 0.35rem 0; color:#111827;">${offer.customerName || offer.customerEmail || 'Customer'} — ${offer.carName || 'Vehicle'}</h4>
                        <p style="margin:0; color:#6b7280; font-size:0.9rem;">📅 ${createdDate.toLocaleString()} • Listed $${listedRate.toFixed(2)} • Offered $${offeredRate.toFixed(2)}</p>
                    </div>
                    <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
                        <span class="status-badge ${statusClass}" style="text-transform: capitalize;">${status}</span>
                        <button class="btn-small btn-edit" onclick="openOfferNegotiation(${Number(offer.id)})">💬 Negotiate</button>
                        <button class="btn-small btn-primary" onclick="acceptPriceOffer(${Number(offer.id)})">✅ Accept</button>
                        <button class="btn-small btn-edit" onclick="counterPriceOffer(${Number(offer.id)})">↔️ Counter</button>
                        <button class="btn-small btn-edit" onclick="rejectPriceOffer(${Number(offer.id)})">❌ Reject</button>
                    </div>
                </div>
                <div style="margin-top:0.75rem; display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:0.5rem 1rem;">
                    <p style="margin:0; color:#374151;"><strong>Email:</strong> ${offer.customerEmail || 'N/A'}</p>
                    <p style="margin:0; color:#374151;"><strong>Phone:</strong> ${offer.customerPhone || 'N/A'}</p>
                    <p style="margin:0; color:#374151;"><strong>Car Model:</strong> ${offer.carModel || 'N/A'}</p>
                    ${offer.ownerResponse ? `<p style="margin:0; color:#374151;"><strong>Owner response:</strong> ${offer.ownerResponse}</p>` : ''}
                    ${lastMessage ? `<p style="margin:0; color:#374151;"><strong>Latest message:</strong> ${lastMessage.text}</p>` : ''}
                </div>
            </div>
        `;
    }).join('');
}

function applyOfferDecision(offerId, decision, options = {}) {
    const { counterRate = null, note = '' } = options;
    const offers = getPriceOffers();
    const offer = offers.find(item => Number(item.id) === Number(offerId));
    if (!offer) {
        showToast('Offer not found.', 'warning');
        return false;
    }

    ensureOfferConversation(offer);

    if (decision === 'accept') {
        offer.status = 'accepted';
        offer.ownerResponse = `Accepted at $${Number(offer.offeredRate || 0).toFixed(2)}/day`;
        addOfferMessage(offer, 'owner', note || offer.ownerResponse, 'decision');
    } else if (decision === 'reject') {
        offer.status = 'rejected';
        offer.ownerResponse = 'Rejected by owner';
        addOfferMessage(offer, 'owner', note || offer.ownerResponse, 'decision');
    } else if (decision === 'counter') {
        if (!Number.isFinite(Number(counterRate)) || Number(counterRate) <= 0) {
            showToast('Please enter a valid counter amount.', 'warning');
            return false;
        }
        offer.status = 'countered';
        offer.counterRate = Number(counterRate);
        offer.ownerResponse = `Countered at $${Number(counterRate).toFixed(2)}/day`;
        addOfferMessage(offer, 'owner', note || offer.ownerResponse, 'counter');
    } else {
        return false;
    }

    offer.updatedAt = new Date().toISOString();
    savePriceOffers(offers);
    renderBargainOffers();
    updateStats();
    renderRevenueAnalytics();
    return true;
}

function openOfferNegotiation(offerId) {
    const offers = getPriceOffers();
    const offer = offers.find(item => Number(item.id) === Number(offerId));
    if (!offer) {
        showToast('Offer not found.', 'warning');
        return;
    }

    ensureOfferConversation(offer);
    savePriceOffers(offers);

    activeNegotiationOfferId = Number(offerId);
    const meta = document.getElementById('offer-negotiation-meta');
    const chat = document.getElementById('offer-negotiation-chat');
    if (!meta || !chat) return;

    const status = String(offer.status || 'pending').toLowerCase();
    meta.innerHTML = `
        <div style="background:#f8fbff; border:1px solid #dbe7f8; border-radius:10px; padding:0.8rem;">
            <h3 style="margin:0 0 0.3rem 0; color:#0f172a;">${offer.customerName || offer.customerEmail || 'Customer'} • ${offer.carName || 'Vehicle'}</h3>
            <p style="margin:0; color:#475569; font-size:0.88rem;">Listed $${Number(offer.listedRate || 0).toFixed(2)} /day • Offered $${Number(offer.offeredRate || 0).toFixed(2)} /day • Status: ${status}</p>
        </div>
    `;

    chat.innerHTML = offer.negotiationMessages.map(message => {
        const bubbleClass = message.sender === 'owner' ? 'owner' : 'customer';
        return `
            <div class="negotiation-bubble ${bubbleClass}">
                <div>${message.text}</div>
                <div class="negotiation-meta">${message.sender === 'owner' ? 'Owner' : 'Customer'} • ${new Date(message.timestamp).toLocaleString()}</div>
            </div>
        `;
    }).join('');

    chat.scrollTop = chat.scrollHeight;
    const messageInput = document.getElementById('offer-negotiation-message');
    if (messageInput) messageInput.value = '';
    const counterInput = document.getElementById('offer-counter-rate');
    if (counterInput) counterInput.value = '';

    showModal('offer-negotiation-modal');
}

function sendNegotiationMessage() {
    if (!activeNegotiationOfferId) return;
    const messageInput = document.getElementById('offer-negotiation-message');
    if (!messageInput) return;

    const text = messageInput.value.trim();
    if (!text) {
        showToast('Type a message first.', 'warning');
        return;
    }

    const offers = getPriceOffers();
    const offer = offers.find(item => Number(item.id) === Number(activeNegotiationOfferId));
    if (!offer) return;

    addOfferMessage(offer, 'owner', text, 'message');
    offer.updatedAt = new Date().toISOString();
    savePriceOffers(offers);
    messageInput.value = '';
    openOfferNegotiation(activeNegotiationOfferId);
    renderBargainOffers();
    showToast('Negotiation message sent.', 'success');
}

function sendCounterFromNegotiation() {
    if (!activeNegotiationOfferId) return;
    const counterInput = document.getElementById('offer-counter-rate');
    const messageInput = document.getElementById('offer-negotiation-message');
    const counterRate = Number(counterInput?.value || 0);
    const note = (messageInput?.value || '').trim();

    const success = applyOfferDecision(activeNegotiationOfferId, 'counter', { counterRate, note });
    if (!success) return;

    if (counterInput) counterInput.value = '';
    if (messageInput) messageInput.value = '';
    openOfferNegotiation(activeNegotiationOfferId);
    showToast('Counter offer sent.', 'success');
}

function acceptPriceOffer(offerId) {
    const ok = applyOfferDecision(offerId, 'accept');
    if (!ok) return;
    showToast(`Offer #${offerId} accepted.`, 'success');
}

function rejectPriceOffer(offerId) {
    const ok = applyOfferDecision(offerId, 'reject');
    if (!ok) return;
    showToast(`Offer #${offerId} rejected.`, 'info');
}

function counterPriceOffer(offerId) {
    const offers = getPriceOffers();
    const offer = offers.find(item => Number(item.id) === Number(offerId));
    if (!offer) {
        showToast('Offer not found.', 'warning');
        return;
    }

    const defaultCounter = Number(offer.listedRate || offer.offeredRate || 0).toFixed(2);
    const counterInput = window.prompt('Enter counter offer per day:', defaultCounter);
    if (counterInput === null) {
        return;
    }

    const ok = applyOfferDecision(offerId, 'counter', { counterRate: Number(counterInput) });
    if (!ok) return;
    showToast(`Counter sent for offer #${offerId}.`, 'success');
}

function approveBookingRequest(requestId) {
    const requests = getBookingRequests();
    const request = requests.find(item => Number(item.id) === Number(requestId));
    if (!request) {
        showToast('Booking request not found.', 'warning');
        return;
    }

    const car = fleet.find(item => item.id === Number(request.carId));
    if (!car || car.status !== 'available') {
        showToast('Requested car is not available right now.', 'warning');
        return;
    }

    request.status = 'active';
    request.approvedAt = new Date().toISOString();
    request.car = request.car || car.name;
    request.carId = request.carId || car.id;

    car.status = 'rented';
    saveBookingRequests(requests);
    syncRentalsFromBookingRequestsCache();
    generateInvoiceFromRental(Number(request.id));
    saveData();

    updateStats();
    renderFleet();
    renderBookingRequests();
    renderRentals();
    renderRentedCarsDetails();
    renderInvoiceCenter();
    populateCarSelect();

    showToast(`Booking approved for ${request.customer || 'Customer'}`, 'success');
}

function rejectBookingRequest(requestId) {
    const requests = getBookingRequests();
    const request = requests.find(item => Number(item.id) === Number(requestId));
    if (!request) {
        showToast('Booking request not found.', 'warning');
        return;
    }

    request.status = 'rejected';
    request.rejectedAt = new Date().toISOString();
    saveBookingRequests(requests);
    renderBookingRequests();
    updateStats();
    showToast('Booking request rejected.', 'info');
}

function parseServiceEventsFromNotes(notesText = '') {
    if (!hasMeaningfulValue(notesText)) return [];

    const markers = ['SCANNER_FORM::', 'SERVICE_EVENT::'];
    const events = [];

    String(notesText)
        .split('\n')
        .map(line => String(line || '').trim())
        .filter(Boolean)
        .forEach(line => {
            const marker = markers.find(item => line.startsWith(item));
            if (!marker) return;

            const rawJson = line.slice(marker.length).trim();
            if (!rawJson) return;

            try {
                const payload = JSON.parse(rawJson);
                events.push(payload);
            } catch {
                // Ignore malformed marker payloads.
            }
        });

    return events;
}

// ===== RENDER SERVICE HISTORY =====
function renderServiceHistory() {
    const historyList = document.getElementById('service-history-list');
    if (!historyList) return;

    const allServices = getBookingRequests()
        .flatMap(request => {
            const events = parseServiceEventsFromNotes(request.notes);
            return events.map(event => ({
                type: String(event.type || 'pickup').toLowerCase() === 'dropoff'
                    ? 'Drop-off'
                    : String(event.type || 'pickup').toLowerCase() === 'swap'
                        ? 'Swap'
                        : 'Pickup',
                serviceRef: event.serviceRef || 'N/A',
                timestamp: event.submittedAt || request.createdAt || new Date().toISOString(),
                customerName: request.customer || 'Customer',
                vehicle: {
                    name: request.car || 'Vehicle',
                    rego: event.vehicleRego || 'N/A'
                }
            }));
        })
        .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
        .slice(0, 8);
    
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
async function handleAddCar(e) {
    if (e) e.preventDefault();
    
    const carName = document.getElementById('car-name')?.value?.trim() || '';
    const carModel = document.getElementById('car-model')?.value?.trim() || '';
    const rateDayInput = parseFloat(document.getElementById('car-rate')?.value || '0');
    const rateWeekInput = parseFloat(document.getElementById('car-rate-week')?.value || '0');
    const mileage = parseInt(document.getElementById('car-mileage')?.value || '0', 10) || 0;
    const fuel = document.getElementById('car-fuel')?.value || 'Full';
    const license = document.getElementById('car-license')?.value?.trim() || '';
    const status = (document.getElementById('car-status')?.value || 'available').trim().toLowerCase();
    const location = document.getElementById('car-location')?.value?.trim() || '';
    const color = document.getElementById('car-color')?.value || 'Unknown';
    const vin = document.getElementById('car-vin')?.value || 'N/A';
    const availabilityText = document.getElementById('car-availability')?.value || '';
    const imageFiles = document.getElementById('car-images')?.files;
    
    if (!carName || !carModel || !license || !location || !Number.isFinite(rateDayInput) || rateDayInput <= 0) {
        showToast('Please fill required fields with valid day price and location.', 'warning');
        return;
    }

    if (!['available', 'rented', 'maintenance'].includes(status)) {
        showToast('Invalid status selected.', 'warning');
        return;
    }

    const normalizedRateDay = normalizeCarRate(rateDayInput);
    const normalizedRateWeek = Number.isFinite(rateWeekInput) && rateWeekInput > 0
        ? Number(rateWeekInput)
        : Number((normalizedRateDay * 6).toFixed(2));
    const availabilityCalendar = parseAvailabilityCalendar(availabilityText);
    const images = (await readImageFilesAsDataUrls(imageFiles)).filter(Boolean).slice(0, 8);
    
    const newCar = {
        id: Math.max(...fleet.map(c => c.id), 0) + 1,
        name: carName,
        model: carModel,
        status,
        rate: normalizedRateDay,
        priceDay: normalizedRateDay,
        priceWeek: normalizedRateWeek,
        mileage: mileage,
        fuel: fuel,
        license: license,
        rego: license,
        location,
        color: color,
        vin: vin,
        images,
        availabilityCalendar
    };
    
    fleet.push(normalizeCarRecord(newCar));
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
            `<option value="${car.id}">${car.name} - ${car.model} ($${normalizeCarRate(car.priceDay ?? car.rate).toFixed(2)}/day)</option>`
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

    const hasCalendarConflict = (Array.isArray(car.availabilityCalendar) ? car.availabilityCalendar : []).some(entry => (
        isDateRangeOverlapping(pickupDate, returnDate, entry.start, entry.end)
    ));

    if (hasCalendarConflict) {
        showToast('Selected vehicle is blocked in availability calendar for these dates.', 'warning');
        return;
    }
    
    // Create new rental
    const newRental = {
        id: rentals.length ? Math.max(...rentals.map(r => Number(r.id) || 0)) + 1 : 1,
        customer: customerName,
        phone: customerPhone,
        email: customerEmail,
        car: car.name,
        carId: car.id,
        pickupDate: pickupDate,
        returnDate: returnDate,
        createdAt: new Date(),
        status: 'active'
    };
    
    // Update car status
    car.status = 'rented';
    
    // Add rental
    rentals.push(newRental);
    const generatedInvoice = generateInvoiceFromRental(newRental.id);
    
    // Save and update
    saveData();
    updateStats();
    renderFleet();
    renderBookingRequests();
    renderRentals();
    renderRentedCarsDetails();
    renderServiceHistory();
    renderInvoiceCenter();
    
    // Close modal and reset form
    closeModal('booking-modal');
    document.getElementById('booking-form').reset();
    initializeBookingDateInputs();
    
    // Show booking summary
    const days = Math.ceil((returnDate - pickupDate) / (1000 * 60 * 60 * 24));
    const total = car.rate * days;
    const summaryMessage = `✅ Booking Created!\n\nCustomer: ${customerName}\nVehicle: ${car.name}\nDays: ${days}\nTotal: $${total}\nInvoice: ${generatedInvoice ? generatedInvoice.invoiceNumber : 'Not generated'}\n\nQR code generated. Ready for pickup!`;
    
    setTimeout(() => {
        showToast(`✅ ${customerName}'s booking confirmed!`, 'success');
        alert(summaryMessage);
        generateCarQR(carId);
    }, 300);
}

function editCar(carId) {
    const car = fleet.find(c => c.id === carId);
    if (!car) return;

    const normalizedCar = normalizeCarRecord(car);

    editingCarId = carId;
    document.getElementById('edit-car-name').value = normalizedCar.name || '';
    document.getElementById('edit-car-make').value = normalizedCar.make || '';
    document.getElementById('edit-car-model').value = normalizedCar.model || '';
    document.getElementById('edit-car-status').value = normalizedCar.status || 'available';
    document.getElementById('edit-car-license').value = normalizedCar.license || '';
    document.getElementById('edit-car-rego').value = normalizedCar.rego || normalizedCar.license || '';
    document.getElementById('edit-car-rate').value = normalizeCarRate(normalizedCar.priceDay ?? normalizedCar.rate);
    document.getElementById('edit-car-rate-week').value = Number(normalizedCar.priceWeek || (normalizeCarRate(normalizedCar.priceDay ?? normalizedCar.rate) * 6)).toFixed(2);
    document.getElementById('edit-car-location').value = normalizedCar.location || 'Main Branch';
    document.getElementById('edit-car-mileage').value = Number(normalizedCar.mileage || 0);
    document.getElementById('edit-car-fuel').value = normalizedCar.fuel || 'N/A';
    document.getElementById('edit-car-color').value = normalizedCar.color || '';
    document.getElementById('edit-car-vin').value = normalizedCar.vin || '';
    document.getElementById('edit-car-availability').value = formatAvailabilityCalendar(normalizedCar.availabilityCalendar);
    const editImageInput = document.getElementById('edit-car-images');
    if (editImageInput) editImageInput.value = '';

    showModal('edit-car-modal');
}

async function handleEditCar(e) {
    if (e) e.preventDefault();
    if (!editingCarId) return;

    const car = fleet.find(c => c.id === editingCarId);
    if (!car) {
        showToast('Vehicle not found', 'error');
        return;
    }

    const nameInput = document.getElementById('edit-car-name').value.trim();
    const makeInput = document.getElementById('edit-car-make').value.trim();
    const modelInput = document.getElementById('edit-car-model').value.trim();
    const statusInput = document.getElementById('edit-car-status').value.trim().toLowerCase();
    const licenseInput = document.getElementById('edit-car-license').value.trim();
    const regoInput = document.getElementById('edit-car-rego').value.trim();
    const rateDayInput = parseFloat(document.getElementById('edit-car-rate').value);
    const rateWeekInput = parseFloat(document.getElementById('edit-car-rate-week').value);
    const locationInput = document.getElementById('edit-car-location').value.trim();
    const mileageInput = parseInt(document.getElementById('edit-car-mileage').value || '0', 10);
    const fuelInput = document.getElementById('edit-car-fuel').value.trim();
    const colorInput = document.getElementById('edit-car-color').value.trim();
    const vinInput = document.getElementById('edit-car-vin').value.trim();
    const availabilityInput = document.getElementById('edit-car-availability').value;
    const imageFiles = document.getElementById('edit-car-images')?.files;

    if (!nameInput || !modelInput || !licenseInput || !locationInput) {
        showToast('Name, model, license, and location are required.', 'warning');
        return;
    }
    if (!['available', 'rented', 'maintenance'].includes(statusInput)) {
        showToast('Invalid status. Use available, rented, or maintenance.', 'warning');
        return;
    }
    if (!Number.isFinite(rateDayInput) || rateDayInput <= 0) {
        showToast('Daily rate must be greater than 0.', 'warning');
        return;
    }
    if (!Number.isFinite(mileageInput) || mileageInput < 0) {
        showToast('Mileage must be a non-negative number.', 'warning');
        return;
    }

    const normalizedRateDay = normalizeCarRate(rateDayInput);
    const normalizedRateWeek = Number.isFinite(rateWeekInput) && rateWeekInput > 0
        ? Number(rateWeekInput)
        : Number((normalizedRateDay * 6).toFixed(2));
    const newImages = (await readImageFilesAsDataUrls(imageFiles)).filter(Boolean).slice(0, 8);

    car.name = nameInput;
    car.make = makeInput;
    car.model = modelInput;
    car.status = statusInput;
    car.license = licenseInput;
    car.rego = regoInput || licenseInput;
    car.location = locationInput;
    car.rate = normalizedRateDay;
    car.priceDay = normalizedRateDay;
    car.priceWeek = normalizedRateWeek;
    car.mileage = mileageInput;
    car.fuel = fuelInput || 'N/A';
    car.color = colorInput;
    car.vin = vinInput;
    car.availabilityCalendar = parseAvailabilityCalendar(availabilityInput);
    if (newImages.length > 0) {
        const existingImages = Array.isArray(car.images) ? car.images : [];
        car.images = [...existingImages, ...newImages].slice(0, 8);
    }

    const activeRental = rentals.find(rental => Number(rental.carId) === Number(car.id) && rental.status === 'active');
    if (activeRental) {
        activeRental.car = car.name;
    }

    normalizeFleetRecords();

    saveData();
    updateStats();
    renderFleet();
    renderBookingRequests();
    renderBargainOffers();
    renderRentals();
    renderRentedCarsDetails();
    populateCarSelect();

    closeModal('edit-car-modal');
    document.getElementById('edit-car-form').reset();
    editingCarId = null;

    showToast(`Updated vehicle: ${car.name}`, 'success');
}

function deleteCar(carId) {
    const car = fleet.find(item => Number(item.id) === Number(carId));
    if (!car) {
        showToast('Vehicle not found.', 'warning');
        return;
    }

    const activeRental = rentals.find(rental => Number(rental.carId) === Number(carId) && rental.status === 'active');
    if (activeRental) {
        showToast('Cannot delete a vehicle with active rental. Complete rental first.', 'warning');
        return;
    }

    const confirmed = window.confirm(`Delete vehicle ${car.name} (${car.license || car.rego || 'N/A'})? This cannot be undone.`);
    if (!confirmed) {
        return;
    }

    fleet = fleet.filter(item => Number(item.id) !== Number(carId));
    saveData();
    updateStats();
    renderFleet();
    renderBookingRequests();
    renderBargainOffers();
    renderRentals();
    renderRentedCarsDetails();
    populateCarSelect();

    if (editingCarId === carId) {
        closeModal('edit-car-modal');
        editingCarId = null;
    }

    showToast(`Deleted vehicle: ${car.name}`, 'success');
}

function showRentalDetails(rentalId) {
    const rental = rentals.find(item => Number(item.id) === Number(rentalId));
    if (!rental) {
        showToast('Rental details not found.', 'warning');
        return;
    }

    const car = fleet.find(item => Number(item.id) === Number(rental.carId));
    const amount = calculateRentalAmount(rental, car);
    const detailContainer = document.getElementById('rental-detail-content');

    if (!detailContainer) {
        showToast('Detail modal is not available in this view.', 'warning');
        return;
    }

    const bookingDate = getBookingReferenceDate(rental);
    const invoice = getRentalInvoice(rental.id);

    detailContainer.innerHTML = `
        <div style="background:#f9fafb; border:1px solid #e5e7eb; border-radius:10px; padding:0.9rem 1rem;">
            <h3 style="margin:0 0 0.35rem 0; color:#111827;">Booking #${rental.id} • ${rental.status || 'active'}</h3>
            <p style="margin:0; color:#6b7280;">Created: ${bookingDate.toLocaleString()}</p>
        </div>
        <div style="display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:0.65rem;">
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Customer</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">${rental.customer || 'N/A'}</p>
                <p style="margin:0.2rem 0 0; color:#6b7280;">📞 ${rental.phone || 'N/A'}</p>
                <p style="margin:0.2rem 0 0; color:#6b7280;">✉️ ${rental.email || 'N/A'}</p>
            </div>
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Vehicle</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">${rental.car || car?.name || 'Vehicle'}</p>
                <p style="margin:0.2rem 0 0; color:#6b7280;">🚗 ${car?.license || car?.rego || 'N/A'}</p>
                <p style="margin:0.2rem 0 0; color:#6b7280;">Status: ${(car?.status || 'unknown').toUpperCase()}</p>
            </div>
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Rental Timeline</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">Pickup: ${new Date(rental.pickupDate).toLocaleString()}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Return: ${new Date(rental.returnDate).toLocaleString()}</p>
                <p style="margin:0.2rem 0 0; color:#6b7280;">Duration: ${amount.totalDays} day(s)</p>
            </div>
            <div style="background:#ffffff; border:1px solid #e5e7eb; border-radius:10px; padding:0.85rem;">
                <strong style="color:#111827;">Financials</strong>
                <p style="margin:0.35rem 0 0; color:#374151;">Rate: $${amount.dailyRate.toFixed(2)} / day</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Subtotal: $${amount.subTotal.toFixed(2)}</p>
                <p style="margin:0.2rem 0 0; color:#374151;">Tax: $${amount.taxAmount.toFixed(2)}</p>
                <p style="margin:0.2rem 0 0; font-weight:700; color:#111827;">Total: $${amount.totalAmount.toFixed(2)}</p>
                <p style="margin:0.2rem 0 0; color:#6b7280;">Invoice: ${invoice ? invoice.invoiceNumber : 'Not generated'}</p>
            </div>
        </div>
        ${rental.notes ? `<div style="background:#fff7ed; border:1px solid #fed7aa; border-radius:10px; padding:0.85rem;"><strong>Notes:</strong> ${rental.notes}</div>` : ''}
    `;

    const invoiceButton = document.getElementById('rental-detail-invoice-btn');
    if (invoiceButton) {
        invoiceButton.onclick = () => openInvoiceForRental(rental.id);
    }

    showModal('rental-detail-modal');
}

function openRentedCarDetails(carId) {
    const activeRental = rentals.find(rental => Number(rental.carId) === Number(carId) && rental.status === 'active');

    if (activeRental) {
        showRentalDetails(activeRental.id);
        return;
    }

    const latestRental = [...rentals]
        .filter(rental => Number(rental.carId) === Number(carId))
        .sort((first, second) => getBookingReferenceDate(second) - getBookingReferenceDate(first))[0];

    if (!latestRental) {
        showToast('No renter information found for this vehicle.', 'warning');
        return;
    }

    showRentalDetails(latestRental.id);
}

function renderInvoiceCenter() {
    const list = document.getElementById('invoice-list');
    const count = document.getElementById('invoice-count');
    if (!list || !count) return;

    count.textContent = invoices.length;

    if (invoices.length === 0) {
        list.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 2rem;">No invoices generated yet</p>';
        return;
    }

    list.innerHTML = invoices.map(invoice => {
        const unpaid = Math.max(0, Number(invoice.totalAmount || 0) - Number(invoice.paidAmount || 0));
        return `
            <div style="background:#fff; border:1px solid #e5e7eb; border-radius:12px; padding:1rem 1.1rem; display:flex; justify-content:space-between; gap:1rem; flex-wrap:wrap;">
                <div>
                    <h4 style="margin:0 0 0.35rem 0; color:#111827;">${invoice.invoiceNumber}</h4>
                    <p style="margin:0; color:#4b5563;">${invoice.customer} • ${invoice.carName}</p>
                    <p style="margin:0.2rem 0 0; color:#6b7280; font-size:0.9rem;">Issued: ${new Date(invoice.issueDate).toLocaleDateString()} • Due: ${new Date(invoice.dueDate).toLocaleDateString()}</p>
                </div>
                <div style="text-align:right;">
                    <p style="margin:0; font-weight:700; color:#111827;">$${Number(invoice.totalAmount || 0).toFixed(2)}</p>
                    <p style="margin:0.2rem 0 0; color:${unpaid > 0 ? '#dc2626' : '#059669'}; font-weight:600;">${unpaid > 0 ? `Unpaid $${unpaid.toFixed(2)}` : 'Paid'}</p>
                    <button class="btn-small btn-primary" style="margin-top:0.45rem;" onclick="openInvoiceByNumber('${invoice.invoiceNumber}')">View</button>
                </div>
            </div>
        `;
    }).join('');
}

function renderInvoiceModal(invoice) {
    const content = document.getElementById('invoice-content');
    if (!content) return;

    const unpaid = Math.max(0, Number(invoice.totalAmount || 0) - Number(invoice.paidAmount || 0));
    content.innerHTML = `
        <div style="border:1px solid #e5e7eb; border-radius:10px; padding:1rem; background:#fff;">
            <div style="display:flex; justify-content:space-between; gap:1rem; flex-wrap:wrap;">
                <div>
                    <h3 style="margin:0 0 0.25rem 0; color:#111827;">${invoice.invoiceNumber}</h3>
                    <p style="margin:0; color:#6b7280;">Issue Date: ${new Date(invoice.issueDate).toLocaleDateString()}</p>
                    <p style="margin:0.2rem 0 0; color:#6b7280;">Due Date: ${new Date(invoice.dueDate).toLocaleDateString()}</p>
                </div>
                <div style="text-align:right;">
                    <p style="margin:0; color:#6b7280;">Status</p>
                    <p style="margin:0.25rem 0 0; font-weight:700; color:${unpaid > 0 ? '#dc2626' : '#059669'};">${unpaid > 0 ? 'OPEN' : 'PAID'}</p>
                </div>
            </div>
        </div>
        <div style="border:1px solid #e5e7eb; border-radius:10px; padding:1rem; background:#fff;">
            <p style="margin:0; color:#374151;"><strong>Customer:</strong> ${invoice.customer}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Phone:</strong> ${invoice.customerPhone || 'N/A'}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Email:</strong> ${invoice.customerEmail || 'N/A'}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Vehicle:</strong> ${invoice.carName}</p>
        </div>
        <div style="border:1px solid #e5e7eb; border-radius:10px; padding:1rem; background:#fff;">
            <p style="margin:0; color:#374151;"><strong>Rental Period:</strong> ${new Date(invoice.pickupDate).toLocaleString()} → ${new Date(invoice.returnDate).toLocaleString()}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Days:</strong> ${invoice.totalDays}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Rate:</strong> $${Number(invoice.dailyRate || 0).toFixed(2)} / day</p>
        </div>
        <div style="border:1px solid #e5e7eb; border-radius:10px; padding:1rem; background:#fff;">
            <p style="margin:0; color:#374151;"><strong>Subtotal:</strong> $${Number(invoice.subTotal || 0).toFixed(2)}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Tax:</strong> $${Number(invoice.taxAmount || 0).toFixed(2)}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Total:</strong> $${Number(invoice.totalAmount || 0).toFixed(2)}</p>
            <p style="margin:0.2rem 0 0; color:#374151;"><strong>Paid:</strong> $${Number(invoice.paidAmount || 0).toFixed(2)}</p>
            <p style="margin:0.2rem 0 0; font-weight:700; color:${unpaid > 0 ? '#dc2626' : '#059669'};"><strong>Outstanding:</strong> $${unpaid.toFixed(2)}</p>
        </div>
    `;

    showModal('invoice-modal');
}

function openInvoiceByNumber(invoiceNumber) {
    const invoice = invoices.find(item => item.invoiceNumber === invoiceNumber);
    if (!invoice) {
        showToast('Invoice not found.', 'warning');
        return;
    }
    renderInvoiceModal(invoice);
}

function openInvoiceForRental(rentalId) {
    const invoice = generateInvoiceFromRental(rentalId);
    if (!invoice) return;

    renderInvoiceCenter();
    renderInvoiceModal(invoice);
    showToast(`Invoice ready: ${invoice.invoiceNumber}`, 'success');
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
    syncInvoiceWithRentalStatus(rental);

    const car = fleet.find(c => c.id === rental.carId);
    if (car) {
        car.status = 'available';
    }

    saveData();
    updateStats();
    renderFleet();
    renderBookingRequests();
    renderRentals();
    renderRentedCarsDetails();
    renderInvoiceCenter();
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
        const rentalDate = getBookingReferenceDate(r);
        const rentalDay = new Date(rentalDate.getFullYear(), rentalDate.getMonth(), rentalDate.getDate());
        return rentalDay.getTime() === today.getTime();
    });
    
    const thisMonthRentals = rentals.filter(r => {
        const rentalDate = getBookingReferenceDate(r);
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
    const finance = getInvoiceFinanceSummary();
    
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

        INVOICES:
        Invoiced This Month: $${finance.invoicedThisMonth.toFixed(2)}
        Unpaid Outstanding: $${finance.totalUnpaid.toFixed(2)}
        
        STATISTICS:
        Completed Rentals: ${analytics.completedRentals}
        Average Rental Days: ${analytics.averageRentalDays}
    `;
    
    alert(reportHTML);
    
    // Option to download CSV
    const csvContent = `Date,Metric,Value\n${new Date().toLocaleDateString()},Today Bookings,${analytics.todayBookings}\n${new Date().toLocaleDateString()},Daily Revenue,$${revenue}\n${new Date().toLocaleDateString()},Fleet Utilization,${utilization}%\n${new Date().toLocaleDateString()},Invoiced This Month,$${finance.invoicedThisMonth.toFixed(2)}\n${new Date().toLocaleDateString()},Outstanding Unpaid,$${finance.totalUnpaid.toFixed(2)}`;
    
    const downloadLink = document.createElement('a');
    downloadLink.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
    downloadLink.setAttribute('download', `report-${new Date().toISOString().split('T')[0]}.csv`);
    downloadLink.click();
}

function exportData() {
    const data = {
        fleet: fleet,
        rentals: rentals,
        invoices: invoices,
        exportDate: new Date().toISOString(),
        analytics: getAnalytics()
    };
    
    const csv = 'Rental,Customer,Car,Pickup,Return,Status,Days,Amount,Invoice\n' + rentals.map(r => {
        const car = fleet.find(c => c.id === r.carId);
        const invoice = getRentalInvoice(r.id);
        const days = Math.ceil((new Date(r.returnDate) - new Date(r.pickupDate)) / (1000 * 60 * 60 * 24));
        const amount = car ? car.rate * days : 0;
        return `${r.id},"${r.customer}","${r.car}","${new Date(r.pickupDate).toLocaleDateString()}","${new Date(r.returnDate).toLocaleDateString()}","${r.status}",${days},$${amount},"${invoice?.invoiceNumber || ''}"`;
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
    renderBookingRequests();
    renderRentals();
    renderRentedCarsDetails();
    renderInvoiceCenter();
}, 60000);
