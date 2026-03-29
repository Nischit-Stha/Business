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

    function getResolvedConfig() {
        const overrideUrl = localStorage.getItem('veera_supabase_url');
        const overrideKey = localStorage.getItem('veera_supabase_publishable_key');

        const runtimeUrl = !isPlaceholder(overrideUrl) ? String(overrideUrl).trim() : config.url;
        const runtimeKey = !isPlaceholder(overrideKey) ? String(overrideKey).trim() : config.publishableKey;

        return { runtimeUrl, runtimeKey, overrideUrl, overrideKey };
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
