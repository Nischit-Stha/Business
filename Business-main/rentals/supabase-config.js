(function () {
    const config = {
        url: 'https://idutrrekubhevckchhdx.supabase.co',
        publishableKey: 'sb_publishable_BdQV0a7sVC_xFqHElVLisg_7FuWSBQG'
    };

    window.VEERA_SUPABASE_CONFIG = config;

    let client = null;

    window.getVeeraSupabaseClient = function getVeeraSupabaseClient() {
        if (client) return client;

        const runtimeUrl = localStorage.getItem('veera_supabase_url') || config.url;
        const runtimeKey = localStorage.getItem('veera_supabase_publishable_key') || config.publishableKey;

        if (!window.supabase || !runtimeUrl || !runtimeKey) {
            return null;
        }

        if (String(runtimeUrl).includes('REPLACE_WITH_') || String(runtimeKey).includes('REPLACE_WITH_')) {
            return null;
        }

        try {
            client = window.supabase.createClient(runtimeUrl, runtimeKey);
            return client;
        } catch (error) {
            console.warn('Supabase client init failed:', error);
            return null;
        }
    };
})();
