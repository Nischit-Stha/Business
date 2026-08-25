import 'server-only';
import { assertProviderAllowed } from '@/lib/env';
import { LocalNotificationProvider, ResendEmailProvider, type NotificationProvider } from '@/lib/notification-provider';

export function createNotificationProvider(environment: Readonly<Record<string,string|undefined>> = process.env): NotificationProvider {
  const provider = environment.EMAIL_PROVIDER ?? 'LOCAL';
  assertProviderAllowed(provider, environment);
  if (provider === 'LOCAL') return new LocalNotificationProvider();
  if (provider === 'RESEND') {
    if (!environment.RESEND_API_KEY || !environment.EMAIL_FROM) throw new Error('RESEND_API_KEY and EMAIL_FROM are required for RESEND.');
    return new ResendEmailProvider({ apiKey: environment.RESEND_API_KEY, from: environment.EMAIL_FROM });
  }
  throw new Error('Unsupported EMAIL_PROVIDER.');
}
