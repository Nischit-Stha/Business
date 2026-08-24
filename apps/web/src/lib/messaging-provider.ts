export type MessageChannel = 'SMS' | 'EMAIL' | 'WHATSAPP';
export type ProviderOutcome =
  | { kind: 'SUCCESS'; providerMessageId: string }
  | { kind: 'TEMPORARY_FAILURE'; code: string; message: string }
  | { kind: 'PERMANENT_FAILURE'; code: string; message: string };

export interface ProviderMessage {
  idempotencyKey: string;
  channel: MessageChannel;
  recipient: string;
  subject: string | null;
  body: string;
}

export interface MessagingProvider {
  readonly name: string;
  readonly supportedChannels: readonly MessageChannel[];
  send(message: ProviderMessage): Promise<ProviderOutcome>;
}

const syntheticSms = /^\+614\d{8}$/;
const syntheticEmail = /^[^@\s]+@example\.(com|test)$/i;

export class FakeMessagingProvider implements MessagingProvider {
  readonly name = 'FAKE';
  readonly supportedChannels = ['SMS', 'EMAIL'] as const;

  async send(message: ProviderMessage): Promise<ProviderOutcome> {
    if (!this.supportedChannels.includes(message.channel as 'SMS' | 'EMAIL')) {
      return { kind: 'PERMANENT_FAILURE', code: 'UNSUPPORTED_CHANNEL', message: 'Fake provider does not send this channel' };
    }
    const valid = message.channel === 'SMS' ? syntheticSms.test(message.recipient) : syntheticEmail.test(message.recipient);
    if (!valid) return { kind: 'PERMANENT_FAILURE', code: 'INVALID_RECIPIENT', message: 'Recipient is not synthetic or is invalid' };
    if (message.recipient.includes('temporary')) return { kind: 'TEMPORARY_FAILURE', code: 'FAKE_TEMPORARY', message: 'Synthetic temporary failure' };
    if (message.recipient.includes('permanent')) return { kind: 'PERMANENT_FAILURE', code: 'FAKE_PERMANENT', message: 'Synthetic permanent failure' };
    return { kind: 'SUCCESS', providerMessageId: `fake:${message.idempotencyKey}` };
  }
}
