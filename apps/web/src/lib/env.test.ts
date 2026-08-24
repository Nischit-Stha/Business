import { describe, expect, it } from 'vitest';
import { readPrivateEnvironment, readPublicEnvironment } from './env';

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

describe('readPrivateEnvironment', () => {
  it('returns configured server-only values', () => {
    expect(readPrivateEnvironment({
      NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
      SUPABASE_SERVICE_ROLE_KEY: 'local-service-key',
    })).toEqual({
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseServiceRoleKey: 'local-service-key',
    });
  });

  it('rejects missing and placeholder service-role keys', () => {
    expect(() => readPrivateEnvironment({ NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321' })).toThrow(/server-only/i);
    expect(() => readPrivateEnvironment({
      NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
      SUPABASE_SERVICE_ROLE_KEY: 'replace-with-local-service-role-key',
    })).toThrow(/server-only/i);
  });
});
