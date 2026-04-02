(function () {
    const config = {
        url: 'https://idutrrekubhevckchhdx.supabase.co',
        publishableKey: 'sb_publishable_BdQV0a7sVC_xFqHElVLisg_7FuWSBQG'
    };

    window.VEERA_SUPABASE_CONFIG = config;

    let client = null;

    function isPlaceholder(value) {
        return !value || String(value).includes('REPLACE_WITH_');
    }

    function isLikelySupabaseUrl(value) {
        if (!value) return false;
        try {
            const parsed = new URL(String(value));
            return parsed.protocol.startsWith('http') && parsed.hostname.includes('supabase.co');
        } catch {
            return false;
        }
    }

    function isLikelySupabaseKey(value) {
        if (!value) return false;
        const text = String(value).trim();
        return text.startsWith('sb_publishable_') || text.startsWith('eyJ');
    }

    function getResolvedConfig() {
        const overrideUrl = localStorage.getItem('veera_supabase_url');
        const overrideKey = localStorage.getItem('veera_supabase_publishable_key');
        const overrideAnonKey = localStorage.getItem('veera_supabase_anon_key');

        const preferredOverrideKey = overrideKey || overrideAnonKey;

        const runtimeUrl = !isPlaceholder(overrideUrl) && isLikelySupabaseUrl(overrideUrl)
            ? String(overrideUrl).trim()
            : config.url;
        const runtimeKey = !isPlaceholder(preferredOverrideKey) && isLikelySupabaseKey(preferredOverrideKey)
            ? String(preferredOverrideKey).trim()
            : config.publishableKey;

        return { runtimeUrl, runtimeKey, overrideUrl, overrideKey: preferredOverrideKey };
    }

    function getCreateClientFn() {
        if (window.supabase && typeof window.supabase.createClient === 'function') {
            return window.supabase.createClient.bind(window.supabase);
        }
        if (window.supabaseJs && typeof window.supabaseJs.createClient === 'function') {
            return window.supabaseJs.createClient.bind(window.supabaseJs);
        }
        if (window.Supabase && typeof window.Supabase.createClient === 'function') {
            return window.Supabase.createClient.bind(window.Supabase);
        }
        return null;
    }

    window.getVeeraSupabaseDebug = function getVeeraSupabaseDebug() {
        const { runtimeUrl, runtimeKey, overrideUrl, overrideKey } = getResolvedConfig();
        return {
            hasWindowSupabase: Boolean(window.supabase),
            hasWindowSupabaseJs: Boolean(window.supabaseJs),
            hasWindowSupabaseCapital: Boolean(window.Supabase),
            hasCreateClientFn: Boolean(getCreateClientFn()),
            runtimeUrl,
            runtimeKeyPrefix: runtimeKey ? String(runtimeKey).slice(0, 24) : null,
            overrideUrl,
            overrideKeyPrefix: overrideKey ? String(overrideKey).slice(0, 24) : null
        };
    };

    window.getVeeraSupabaseClient = function getVeeraSupabaseClient() {
        if (client) return client;

        const { runtimeUrl, runtimeKey } = getResolvedConfig();
        const createClient = getCreateClientFn();

        if (!createClient || !runtimeUrl || !runtimeKey) {
            return null;
        }

        if (isPlaceholder(runtimeUrl) || isPlaceholder(runtimeKey)) {
            return null;
        }

        try {
            client = createClient(runtimeUrl, runtimeKey);
            return client;
        } catch (error) {
            console.warn('Supabase client init failed:', error);
            return null;
        }
    };
})();
