(function attachVeeraSharedUtils(globalScope) {
    const scope = globalScope || window;

    function getSupabaseClient() {
        if (typeof scope.getVeeraSupabaseClient === 'function') {
            return scope.getVeeraSupabaseClient();
        }
        return null;
    }

    function hasMeaningfulValue(value) {
        if (value === null || value === undefined) return false;
        const text = String(value).trim().toLowerCase();
        return text !== '' && text !== 'n/a' && text !== 'na' && text !== 'unknown' && text !== '-';
    }

    function sanitizeText(value, fallback) {
        return hasMeaningfulValue(value) ? String(value).trim() : (fallback ?? 'N/A');
    }

    scope.VeeraShared = {
        getSupabaseClient,
        hasMeaningfulValue,
        sanitizeText
    };
})(typeof window !== 'undefined' ? window : undefined);
