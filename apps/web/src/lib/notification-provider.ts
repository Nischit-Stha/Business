export type NotificationChannel = 'SMS' | 'EMAIL' | 'WHATSAPP' | 'INTERNAL';
export type NotificationOutcome = { kind: 'SUCCESS'; providerMessageId: string } | { kind: 'TEMPORARY_FAILURE' | 'PERMANENT_FAILURE'; message: string };
export type OutboundNotification = { id: string; channel: NotificationChannel; recipient: string | null; subject: string | null; renderedMessage: string };

export interface NotificationProvider {
  readonly name: string;
  deliver(notification: OutboundNotification): Promise<NotificationOutcome>;
}

export type ResendProviderOptions = { apiKey: string; from: string; fetch?: typeof globalThis.fetch };

/** Production-capable email adapter. Responses are reduced to safe categories; bodies are never logged. */
export class ResendEmailProvider implements NotificationProvider {
  readonly name = 'RESEND';
  private readonly request: typeof globalThis.fetch;
  constructor(private readonly options: ResendProviderOptions) { this.request = options.fetch ?? globalThis.fetch; }
  async deliver(notification: OutboundNotification): Promise<NotificationOutcome> {
    if (notification.channel !== 'EMAIL' || !notification.recipient) return { kind: 'PERMANENT_FAILURE', message: 'INVALID_RECIPIENT' };
    try {
      const response = await this.request('https://api.resend.com/emails', {
        method: 'POST', headers: { Authorization: `Bearer ${this.options.apiKey}`, 'Content-Type': 'application/json', 'Idempotency-Key': `veera-notification-${notification.id}` },
        body: JSON.stringify({ from: this.options.from, to: [notification.recipient], subject: notification.subject ?? 'Veera Rentals', text: notification.renderedMessage }),
        signal: AbortSignal.timeout(15_000),
      });
      if (response.ok) { const body = await response.json() as { id?: string }; return body.id ? { kind: 'SUCCESS', providerMessageId: body.id } : { kind: 'TEMPORARY_FAILURE', message: 'PROVIDER_UNAVAILABLE' }; }
      if (response.status === 429) return { kind: 'TEMPORARY_FAILURE', message: 'RATE_LIMIT' };
      if (response.status >= 500) return { kind: 'TEMPORARY_FAILURE', message: 'PROVIDER_UNAVAILABLE' };
      return { kind: 'PERMANENT_FAILURE', message: response.status === 422 ? 'INVALID_RECIPIENT' : 'REJECTED' };
    } catch (error) {
      return { kind: 'TEMPORARY_FAILURE', message: error instanceof DOMException && error.name === 'TimeoutError' ? 'TIMEOUT' : 'PROVIDER_UNAVAILABLE' };
    }
  }
}

/** Local/staging-only adapter. It records synthetic outcomes and never opens a network connection. */
export class LocalNotificationProvider implements NotificationProvider {
  readonly name = 'LOCAL';
  async deliver(notification: OutboundNotification): Promise<NotificationOutcome> {
    if (notification.recipient?.includes('temporary')) return { kind: 'TEMPORARY_FAILURE', message: 'Simulated temporary failure' };
    if (notification.recipient?.includes('permanent')) return { kind: 'PERMANENT_FAILURE', message: 'Simulated permanent failure' };
    return { kind: 'SUCCESS', providerMessageId: `local:${notification.id}` };
  }
}
