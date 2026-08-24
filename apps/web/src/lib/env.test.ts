import { describe, expect, it } from 'vitest';
import { readPublicEnvironment } from './env';

describe('readPublicEnvironment', () => {
  it('returns configured local values', () => {
    expect(
      readPublicEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
        NEXT_PUBLIC_SUPABASE_ANON_KEY: 'local-test-key',
      }),
    ).toEqual({
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'local-test-key',
    });
  });

  it('rejects missing configuration', () => {
    expect(() => readPublicEnvironment({})).toThrow(/must contain local or staging values/);
  });

  it('rejects the documented placeholder key', () => {
    expect(() =>
      readPublicEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
        NEXT_PUBLIC_SUPABASE_ANON_KEY: 'replace-with-local-anon-key',
      }),
    ).toThrow(/must contain local or staging values/);
  });
});
