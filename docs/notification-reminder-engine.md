# Notification and reminder engine

Veera V2 stores provider-neutral notifications in PostgreSQL. The engine renders controlled templates once, schedules work with a unique business-stage key, leases due rows to a worker, and preserves sent content as immutable history.

## Safe local operation

`LocalNotificationProvider` is the only notification adapter. It performs no network request and returns `local:<notification-id>` identifiers. Synthetic recipients containing `temporary` or `permanent` simulate failures. No SMS, email, WhatsApp, banking credential, or production endpoint is configured.

## Scheduling

`generate_notifications()` is an authenticated staff RPC suitable for a future scheduler. Defaults are stored in `notification_settings`: payment due day and 1/3/7 days overdue, licence 30/14/7 days and expiry, and pickup/return 24 hours and same-day. Unique `dedup_key` values make repeated generation safe. The generator cancels unsent payment, service, pickup, and return reminders when the underlying condition clears.

The queue worker claims due rows with `FOR UPDATE SKIP LOCKED` and expiring leases. Completion requires the matching claim token. Temporary failures use bounded exponential backoff; terminal repeated failures create owner-attention exceptions.

## Security and content

Tables are deny-by-default under RLS and staff-readable only. All writes use staff-authorized security-definer RPCs. Templates use `{{safe_variable}}` substitution with a per-template allow-list; unknown or missing variables fail rendering. Templates contain no licence numbers, addresses, document URLs, banking descriptions, or issue notes. Customer history exposes only time, type, channel, and status.

## Future scheduler

A scheduler should authenticate as a tightly scoped server principal, call `generate_notifications`, then invoke the server-side worker. It must not call delivery RPCs from a browser or embed a service-role key in the web bundle.

## Before a real provider

- Implement provider adapters behind `NotificationProvider`, with secret management outside source control.
- Add verified sender identities, delivery webhooks, signature verification, and mapping from provider receipts to `DELIVERED`.
- Add production-grade consent, quiet-hours/time-zone, rate-limit, bounce, complaint, and WhatsApp template-approval handling.
- Establish monitoring, dead-letter operations, retention policy, provider idempotency guarantees, and staging certification.
- Security-review recipient validation and approve each customer-facing template before activation.
