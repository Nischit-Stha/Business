# Private document storage security

## Design

Veera stores file bytes only in two private Supabase Storage buckets: `customer-documents` for driver licences and proof of address, and `vehicle-compliance-documents` for registration and RWC evidence. Both buckets are migration-managed, explicitly non-public, limited to 10 MiB, and restricted to PDF, JPEG, and PNG. PostgreSQL stores metadata only.

Objects use generated, non-reused paths such as `customers/<customer UUID>/driver_licence/<random UUID>.pdf`. Original filenames are display metadata and never form part of an object path. The server normalizes filenames, replaces path separators/control characters, detects the file type from magic bytes, computes SHA-256, and uploads with `upsert: false`. The database independently validates the bucket, subject-scoped path, extension, MIME allowlist, size, checksum shape, and filename.

## Access model and signed URLs

Access is deny-by-default. Anonymous users have no metadata or object policy. Only authenticated staff whose `staff_profiles` row is active and has role `ADMIN` or `STAFF` pass `app_private.is_staff()`. Storage has no update or delete policy, preventing silent overwrite and casual evidence deletion. A narrowly scoped insert policy supports the server action under the staff session; the supported UI does not expose a browser storage client.

The view server action rechecks active staff status, atomically records `VIEW_LINK_GENERATED`, and requests a 60-second signed URL. The UI never persists or constructs a public URL. Signed URLs are bearer credentials during their brief lifetime and must not be copied into logs or analytics. Policies and functions are structured around a single staff predicate so document-type permissions can later replace it.

## Validation and limits

Allowed formats are genuine PDF (`%PDF-`), JPEG, and PNG files, with a maximum size of 10 MiB. A client `accept` attribute is only a usability hint; server magic-byte checks are authoritative. Executables, Office archives, HTML/SVG, empty files, mismatched content, oversized files, control-character filenames, traversal paths, and reused object paths are rejected. MIME detection is deliberately conservative; changing the allowlist requires coordinated application, bucket, database, and test changes.

## Versioning, verification, expiry, and retention

Each upload creates a new `document_versions` row. Replacement atomically marks the prior submitted/verified version `SUPERSEDED`, links it to its successor, and retains its storage object and verification history. Verify/reject decisions update the active customer or vehicle readiness metadata. Driver licence expiry therefore blocks customer readiness; expired registration or RWC blocks vehicle compliance/pickup. Existing owner exceptions remain reporting/management aids and do not bypass these server-side readiness checks.

Historical evidence has no routine deletion workflow. A future retention policy must account for regulatory, dispute, privacy, and legal-hold requirements and should use an approved, audited purge job—not ad hoc object deletion.

## Audit log

`document_access_events` is append-only to authenticated application roles and records actor, document version, timestamp, action, and minimal context for `UPLOAD`, `VIEW_LINK_GENERATED`, `VERIFY`, `REJECT`, and `SUPERSEDE`. It never records bytes, licence numbers, addresses, signed URLs, or extracted document values.

## Threat model

Primary threats are unauthenticated access, inactive-account reuse, authorization bypass, public-bucket mistakes, signed-link leakage, path traversal, filename/content spoofing, oversized-file denial of service, overwrite/replay, and history destruction. Controls include private bucket flags, active-staff RLS and RPC checks, short URL lifetime, random immutable paths, server and database validation, checksums, no update/delete policy, and immutable access events.

Files are not yet malware-scanned. The future hook should quarantine new objects, scan asynchronously with an isolated scanner, record the scan engine/signature/result, and permit verification/viewing only after a clean result. Until then, staff should treat downloads as untrusted and avoid uploading active content.

## Production deployment

Deploy only through the reviewed forward migration to a separately controlled staging project first. Confirm bucket privacy, size/MIME configuration, RLS policies, JWT role behavior, signed-link expiry, audit insertion, backup/restore, retention, and failed-upload orphan monitoring. Keep service-role keys and database credentials server-side; this implementation does not add a service-role key to the browser or source. Do not migrate real customer files until staging security review, malware scanning, operational retention policy, and incident-response procedures are approved.
