import 'server-only';
import { FakeMessagingProvider, type MessagingProvider } from '@/lib/messaging-provider';

type Delivery = { id: string; claim_token: string; channel: 'SMS'|'EMAIL'|'WHATSAPP'; recipient: string; subject: string|null; body: string };
type RpcResult = { data: unknown; error: { message: string } | null };
type RpcClient = { rpc(name: string, args: Record<string, unknown>): PromiseLike<RpcResult> };

export async function runDeliveryWorker(client: RpcClient, limit = 10, provider: MessagingProvider = new FakeMessagingProvider()) {
  const claim = await client.rpc('claim_message_deliveries', { p_limit: limit, p_lease_seconds: 60 });
  if (claim.error) throw new Error(claim.error.message);
  const deliveries = (claim.data ?? []) as Delivery[];
  const results = [];
  for (const delivery of deliveries) {
    const outcome = await provider.send({ idempotencyKey: delivery.id, channel: delivery.channel, recipient: delivery.recipient, subject: delivery.subject, body: delivery.body });
    const completion = await client.rpc('complete_message_delivery', {
      p_delivery_id: delivery.id, p_claim_token: delivery.claim_token, p_outcome: outcome.kind,
      p_provider_message_id: outcome.kind === 'SUCCESS' ? outcome.providerMessageId : null,
      p_error_code: outcome.kind === 'SUCCESS' ? null : outcome.code,
      p_error: outcome.kind === 'SUCCESS' ? null : outcome.message,
    });
    if (completion.error) throw new Error(completion.error.message);
    results.push(completion.data);
  }
  return results;
}
