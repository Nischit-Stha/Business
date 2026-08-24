import { describe, expect, it } from 'vitest';
import { FakeMessagingProvider } from './messaging-provider';

const base = { idempotencyKey: 'delivery-1', channel: 'EMAIL' as const, subject: 'Test', body: 'Synthetic body' };
describe('FakeMessagingProvider', () => {
  it('returns stable fake success identifiers', async () => expect(await new FakeMessagingProvider().send({ ...base, recipient: 'success@example.test' })).toEqual({ kind: 'SUCCESS', providerMessageId: 'fake:delivery-1' }));
  it('models retryable failures', async () => expect((await new FakeMessagingProvider().send({ ...base, recipient: 'temporary@example.test' })).kind).toBe('TEMPORARY_FAILURE'));
  it('models permanent failures', async () => expect((await new FakeMessagingProvider().send({ ...base, recipient: 'permanent@example.test' })).kind).toBe('PERMANENT_FAILURE'));
  it('rejects real recipients', async () => expect((await new FakeMessagingProvider().send({ ...base, recipient: 'person@real-domain.com' })).kind).toBe('PERMANENT_FAILURE'));
});
