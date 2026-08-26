/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    // Use the stable TypeScript compiler API until the CLI path leaves experimental status.
    useTypeScriptCli: false,
  },
  poweredByHeader: false,
  reactStrictMode: true,
  async headers() {
    const development = process.env.VEERA_RUNTIME_MODE === 'development' || !process.env.VEERA_RUNTIME_MODE;
    const scriptPolicy = development ? "script-src 'self' 'unsafe-inline' 'unsafe-eval'" : "script-src 'self' 'unsafe-inline'";
    const connectPolicy = development ? "connect-src 'self' https://*.supabase.co wss://*.supabase.co http://127.0.0.1:54321 ws://127.0.0.1:54321" : "connect-src 'self' https://*.supabase.co wss://*.supabase.co";
    const securityHeaders = [
      { key: 'Content-Security-Policy', value: `default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; img-src 'self' data: blob:; font-src 'self'; style-src 'self' 'unsafe-inline'; ${scriptPolicy}; ${connectPolicy}${development?'':'; upgrade-insecure-requests'}` },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), payment=(), usb=()' },
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
    ];
    if (!development) {
      securityHeaders.push({ key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' });
    }
    return [{ source: '/:path*', headers: securityHeaders }];
  },
};

export default nextConfig;
