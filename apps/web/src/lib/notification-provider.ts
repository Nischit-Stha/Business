export type NotificationChannel = 'SMS' | 'EMAIL' | 'WHATSAPP' | 'INTERNAL';
export type NotificationOutcome = { kind: 'SUCCESS'; providerMessageId: string } | { kind: 'TEMPORARY_FAILURE' | 'PERMANENT_FAILURE'; message: string };
export type OutboundNotification = { id: string; channel: NotificationChannel; recipient: string | null; subject: string | null; renderedMessage: string };

export interface NotificationProvider {
  readonly name: string;
  deliver(notification: OutboundNotification): Promise<NotificationOutcome>;
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
