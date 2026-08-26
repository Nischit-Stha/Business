import { describe, expect, it } from 'vitest';
// @ts-expect-error Next configuration is an ESM JavaScript module without declarations.
import nextConfig from '../../next.config.mjs';

describe('security headers', () => {
  it('denies framing, sniffing, dangerous capabilities, and executable objects', async () => {
    const rules = await nextConfig.headers!();
    const headers = Object.fromEntries(rules[0].headers.map(({ key, value }: {key:string;value:string}) => [key, value]));
    expect(headers['X-Frame-Options']).toBe('DENY');
    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['Content-Security-Policy']).toContain("frame-ancestors 'none'");
    expect(headers['Content-Security-Policy']).toContain("object-src 'none'");
    expect(headers['Permissions-Policy']).toContain('camera=()');
  });
});
