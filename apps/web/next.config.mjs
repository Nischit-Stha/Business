/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    // Use the stable TypeScript compiler API until the CLI path leaves experimental status.
    useTypeScriptCli: false,
  },
  poweredByHeader: false,
  reactStrictMode: true,
};

export default nextConfig;
