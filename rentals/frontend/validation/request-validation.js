(function attachVeeraValidation(globalScope) {
    const scope = globalScope || window;

    function normalizeText(value) {
        return String(value || '').trim();
    }

    function isValidName(name) {
        const text = normalizeText(name);
        if (text.length < 2 || text.length > 80) return false;
        return /^[A-Za-z][A-Za-z\s'\-.]{1,79}$/.test(text);
    }

    function isValidPhone(phone) {
        const text = normalizeText(phone).replace(/[\s()-]/g, '');
        if (!text) return false;
        return /^(\+?\d{8,15})$/.test(text);
    }

    function isValidEmail(email) {
        const text = normalizeText(email).toLowerCase();
        if (!text) return false;
        return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(text);
    }

    function isValidRego(rego) {
        const text = normalizeText(rego).toUpperCase();
        if (text.length < 2 || text.length > 12) return false;
        return /^[A-Z0-9\-\s]+$/.test(text);
    }

    function isValidMileage(mileage) {
        const value = Number(mileage);
        return Number.isFinite(value) && value >= 0 && value <= 2000000;
    }

    function isValidRequestType(requestType) {
        return ['pickup', 'dropoff', 'swap'].includes(String(requestType || '').toLowerCase());
    }

    function validateServicePayload(payload) {
        const errors = [];
        const requestType = String(payload?.requestType || '').toLowerCase();

        if (!isValidRequestType(requestType)) {
            errors.push('Invalid request type.');
        }

        if (requestType === 'pickup') {
            if (!isValidName(payload?.name)) {
                errors.push('Please enter a valid customer name.');
            }
            if (!isValidPhone(payload?.phone)) {
                errors.push('Please enter a valid phone number.');
            }
            if (!isValidEmail(payload?.email)) {
                errors.push('Please enter a valid email address.');
            }
            if (!Array.isArray(payload?.photos) || payload.photos.length === 0) {
                errors.push('Driver license photo is required for pickup.');
            }
        }

        if (!isValidRego(payload?.rego)) {
            errors.push('Invalid vehicle registration (rego).');
        }

        if (!isValidMileage(payload?.mileage)) {
            errors.push('Mileage must be a valid non-negative number.');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    scope.VeeraValidation = {
        isValidName,
        isValidPhone,
        isValidEmail,
        isValidRego,
        isValidMileage,
        isValidRequestType,
        validateServicePayload
    };
})(typeof window !== 'undefined' ? window : undefined);
