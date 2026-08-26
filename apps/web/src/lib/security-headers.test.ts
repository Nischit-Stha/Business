import { afterEach, describe, expect, it, vi } from 'vitest';
// @ts-expect-error Next configuration is an ESM JavaScript module without declarations.
import nextConfig from '../../next.config.mjs';

describe('security headers', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  async function getHeaders() {
    const rules = await nextConfig.headers!();
    return Object.fromEntries(
      rules[0].headers.map(({ key, value }: { key: string; value: string }) => [key, value]),
    );
  }

  it('denies framing, sniffing, dangerous capabilities, and executable objects', async () => {
    const headers = await getHeaders();
    expect(headers['X-Frame-Options']).toBe('DENY');
    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['Content-Security-Policy']).toContain("frame-ancestors 'none'");
    expect(headers['Content-Security-Policy']).toContain("object-src 'none'");
    expect(headers['Permissions-Policy']).toContain('camera=()');
  });

  it("allows eval in development for Next.js and React tooling", async () => {
    vi.stubEnv('NODE_ENV', 'development');

    const headers = await getHeaders();

    expect(headers['Content-Security-Policy']).toContain("script-src 'self' 'unsafe-inline' 'unsafe-eval'");
  });

  it("does not allow eval in production", async () => {
    vi.stubEnv('NODE_ENV', 'production');

    const headers = await getHeaders();

    expect(headers['Content-Security-Policy']).toContain("script-src 'self' 'unsafe-inline'");
    expect(headers['Content-Security-Policy']).not.toContain("'unsafe-eval'");
  });
});
