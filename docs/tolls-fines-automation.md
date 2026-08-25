# Tolls and fines automation

Veera V2 now has a provider-neutral internal workflow for synthetic toll and infringement data. It does not call Starr365, toll providers, VicRoads, infringement agencies, or government services.

## Internal boundary

The durable record and workflow support these future adapter operations:

```ts
interface TollFineProviderAdapter {
  importRecords(input: ProviderImportRequest): Promise<ProviderImportResult>;
  lookupExternalRecord(externalReference: string): Promise<ExternalRecord | null>;
  submitTransfer(request: TransferRequest): Promise<TransferReceipt>;
  confirmTransferStatus(receipt: TransferReceipt): Promise<TransferStatus>;
}
```

No API shape, authentication scheme, webhook support, or transfer semantics are assumed. A future adapter must map provider data into the existing provider-neutral staging contract and preserve the source payload/checksum. Network operations must run server-side with idempotency, retry controls, and credential management outside source control.

## Current workflow

Synthetic CSV and manual records are validated server-side, matched against registration and effective custody periods, and placed into `MATCHED` only for one clear, consistent custody candidate. Staff confirm or override the suggestion, then explicitly progress `CONFIRMED → TRANSFER_PENDING → TRANSFERRED`. Historical match evidence, decisions, and status history are append-only.

The customer-safe database projection deliberately returns no rows and is not granted to customers. Owner attention contains only deduplicated exceptions: high-value unresolved fines, ambiguity, overdue transfers, repeated unmatched events, disputes, and custody inconsistencies.

## Before enabling Starr365

- Confirm Starr365 capabilities, authentication, rate limits, data contract, and sandbox availability.
- Obtain legal/business approval for nomination/transfer semantics and any customer disclosure.
- Build the adapter behind the interface above with staging credentials only.
- Add signed request/webhook verification, retry/dead-letter behavior, reconciliation, and provider contract tests.
- Define production rollout, monitoring, incident response, and credential rotation.
