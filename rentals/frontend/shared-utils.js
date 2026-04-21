(function attachVeeraSharedUtils(globalScope) {
    const scope = globalScope || window;

    function readStore(key, fallback = []) {
        try {
            const raw = scope.localStorage?.getItem(key);
            return raw ? JSON.parse(raw) : fallback;
        } catch (error) {
            console.warn(`Failed to read storage key ${key}:`, error);
            return fallback;
        }
    }

    function writeStore(key, value) {
        try {
            scope.localStorage?.setItem(key, JSON.stringify(value));
            return value;
        } catch (error) {
            console.warn(`Failed to write storage key ${key}:`, error);
            return value;
        }
    }

    function appendStoreItem(key, item, limit = 100) {
        const current = Array.isArray(readStore(key, [])) ? readStore(key, []) : [];
        const next = [item, ...current].slice(0, limit);
        writeStore(key, next);
        return next;
    }

    function downloadTextFile(filename, content, mimeType = 'text/plain;charset=utf-8') {
        const blob = new Blob([content], { type: mimeType });
        const url = URL.createObjectURL(blob);
        const link = scope.document.createElement('a');
        link.href = url;
        link.download = filename;
        link.style.display = 'none';
        scope.document.body.appendChild(link);
        link.click();
        link.remove();
        URL.revokeObjectURL(url);
    }

    function showNotice(message, type = 'info') {
        const noticeId = 'veera-notice';
        let notice = scope.document.getElementById(noticeId);
        if (!notice) {
            notice = scope.document.createElement('div');
            notice.id = noticeId;
            notice.style.position = 'fixed';
            notice.style.right = '16px';
            notice.style.bottom = '16px';
            notice.style.zIndex = '9999';
            notice.style.maxWidth = '360px';
            notice.style.padding = '12px 14px';
            notice.style.borderRadius = '12px';
            notice.style.boxShadow = '0 16px 40px rgba(0,0,0,.22)';
            notice.style.font = '600 14px/1.4 Inter, sans-serif';
            notice.style.color = '#fff';
            scope.document.body.appendChild(notice);
        }

        const colors = {
            success: '#1d9f70',
            warning: '#c78924',
            error: '#d84b61',
            info: '#0069d9'
        };

        notice.textContent = message;
        notice.style.background = colors[type] || colors.info;
        notice.style.display = 'block';
        clearTimeout(notice._veeraTimer);
        notice._veeraTimer = scope.setTimeout(() => { notice.style.display = 'none'; }, 3500);
    }

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
        sanitizeText,
        readStore,
        writeStore,
        appendStoreItem,
        downloadTextFile,
        showNotice
    };
})(typeof window !== 'undefined' ? window : undefined);
