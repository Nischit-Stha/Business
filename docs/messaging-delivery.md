# Veera V2 staged messaging and reminder delivery

## Scope and safety boundary

This stage delivers a provider-independent queue and a server-side `FAKE` provider. It does **not** connect to an SMS, email, or WhatsApp network, contain provider credentials, or permit browser code to select a provider. The fake provider accepts only Australian synthetic mobile numbers in `+614xxxxxxxx` form and email addresses under `example.com` or `example.test`.

The provider interface supports `SMS`, `EMAIL`, and a reserved `WHATSAPP` channel. The fake implementation advertises only SMS and email. Adding a real provider requires a separately reviewed server-only adapter, secret management, webhook authentication, delivery-receipt reconciliation, staging approval, and legal/compliance approval.

## Data model

- `message_templates` contains the ten version-one reminder purposes and their channel-specific subject/body text.
- `customer_communication_preferences` records SMS/email opt-outs, a required suppression reason, the staff actor, and timestamps.
- `message_deliveries` is the durable queue. A stable `logical_key` prevents duplicate generation, while `reminder_action_id` is unique so one payment reminder action can produce at most one logical delivery.
- Delivery states are `QUEUED`, `SENDING`, `SENT`, `DELIVERED`, `RETRY_WAIT`, `FAILED`, `CANCELLED`, and `SUPPRESSED`.

Template data is rendered into a body at enqueue time so later template edits cannot silently alter an already approved delivery.

## Generation and suppression

`run_collection_workflows` creates payment reminder actions and linked deliveries in one transaction. First, second, escalation, and staff-call stages map to payment templates; each action remains the idempotency source. An active, unexpired promise-to-pay prevents generation and suppresses a pending linked delivery. If arrears clear before send, pending linked deliveries are cancelled during workflow or claim preflight.

`generate_message_reminders` creates stable logical reminders for service due, licence expiry, registration expiry, RWC expiry, missing documents, pickups, and returns. Re-running it does not duplicate the same logical event.

Channel opt-outs are applied before queueing. Missing, invalid, or non-synthetic contacts are suppressed. Missing and invalid contacts create deduplicated operational exceptions; opt-outs are normal suppressions and do not create contact-quality exceptions.

## Worker and failure handling

`claim_message_deliveries` atomically selects eligible work with `FOR UPDATE SKIP LOCKED`, changes it to `SENDING`, increments its bounded attempt count, and issues a unique claim token with a short lease. Multiple workers are safe and expired work can be reclaimed. The delivery UUID is the provider idempotency key.

Only the holder of the live claim token can report an outcome. Success becomes `SENT`. Temporary failure uses bounded exponential backoff and becomes `RETRY_WAIT`, or `FAILED` at the retry limit. Permanent failure stops immediately. Repeated terminal failures and stuck leases create owner-only, deduplicated exceptions. Staff may retry only known safe temporary error codes and cancel only queued or retry-waiting deliveries.

The fake worker is deliberately invoked from the staff Messaging page. A future scheduler should authenticate as a dedicated least-privilege server principal.

## Authorization and staff workflow

All messaging tables have RLS enabled and deny access by default. Active staff receive read-only policies. State changes occur through security-definer functions that independently check `app_private.is_staff()`. Inactive staff and non-staff users cannot read the queue or invoke worker/staff operations. Internal rendering and enqueue functions are not executable by browser roles.

`/messaging` groups deliveries into queued, retrying, sent, failed, and suppressed views. Staff can inspect delivery details; generate reminder candidates; run the fake worker; retry safe failures; and cancel pending deliveries.

## Production legal and compliance gate

No real delivery may be enabled until counsel/compliance owners approve, document, and test at least:

- consent and lawful-basis rules per channel, including Australian Spam Act and Do Not Call obligations;
- transactional-versus-marketing classification, sender identification, opt-out wording/timing, and contact windows;
- vulnerable-customer and collections conduct, promise-to-pay treatment, and escalation copy;
- privacy notices, minimisation, retention/deletion, cross-border processing, subprocessors, and breach handling;
- template ownership/version approval, preference provenance, suppression migration, complaints, and audit retention;
- provider security, credential rotation, webhook verification, receipts, rate limits, spend controls, and rollback.

Until that review is signed off, only synthetic recipients and the fake provider are allowed. Production credentials must never be committed, logged, placed in `NEXT_PUBLIC_*`, or sent to the browser.

## Local verification

Run the repository verification suite plus `supabase/tests/messaging_delivery_test.sql`. Tests cover logical uniqueness, fake outcomes, bounded retry, payment clearing, opt-out/missing-contact suppression, repeated-failure exceptions, disjoint queue claims, RLS, and inactive staff denial.
