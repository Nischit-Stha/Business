import 'server-only';
import { LocalNotificationProvider, type NotificationProvider } from '@/lib/notification-provider';

type Row = { id: string; claim_token: string; channel: 'SMS'|'EMAIL'|'WHATSAPP'|'INTERNAL'; recipient: string|null; subject: string|null; rendered_message: string };
type Client = { rpc(name: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: { message: string } | null }> };

export async function runNotificationWorker(client: Client, limit = 20, provider: NotificationProvider = new LocalNotificationProvider()) {
  const claimed = await client.rpc('claim_notifications', { p_limit: limit, p_lease_seconds: 60 });
  if (claimed.error) throw new Error(claimed.error.message);
  const results = [];
  for (const row of (claimed.data ?? []) as Row[]) {
    const started = performance.now();
    const outcome = await provider.deliver({ id: row.id, channel: row.channel, recipient: row.recipient, subject: row.subject, renderedMessage: row.rendered_message });
    const completed = await client.rpc('complete_notification', { p_id: row.id, p_claim_token: row.claim_token, p_outcome: outcome.kind, p_provider_message_id: outcome.kind === 'SUCCESS' ? outcome.providerMessageId : null, p_failure_reason: outcome.kind === 'SUCCESS' ? null : outcome.message, p_safe_error_category: outcome.kind === 'SUCCESS' ? null : 'UNKNOWN', p_duration_ms: Math.round(performance.now()-started), p_provider: 'LOCAL_SYNTHETIC' });
    if (completed.error) throw new Error(completed.error.message);
    results.push(completed.data);
  }
  return results;
}
