# Future data migration runbook

Do not import real Veera data during development. This is the reviewed future pipeline design.

1. Export customers, vehicles, agreements, current custody, opening payment schedules/balances, maintenance and document inventory into separate encrypted CSV manifests.
2. Copy to a restricted staging area outside source control. Record source checksum, extract time, owner and row count.
3. **Dry-run:** validate types, required fields, dates, registrations/licences, foreign-key references, duplicate natural keys and unsupported legal/payment states. Produce accepted/rejected CSVs without writes.
4. Resolve rejected records with business owners. Never silently invent contract totals, payment history or custody dates.
5. Import into dedicated staging tables. Use one reviewed atomic promotion operation per domain in dependency order: customers → vehicles → agreements → assignments → schedules/opening balances → maintenance → document metadata.
6. Preserve source IDs in a restricted mapping table and produce source-to-target counts/checksums. Financial opening entries must be attributable migration entries; never rewrite later ledger history.
7. Reconcile counts, active custody, outstanding totals and sampled records. Run RLS/UAT/security tests.
8. Rollback before promotion by dropping the isolated staging import. After promotion, use backup restore or a reviewed compensating migration—never ad-hoc deletes from financial/audit history.
9. Store the signed migration report: inputs/checksums, rejects, mappings, totals, operator, reviewer, timestamps and go/no-go decision.

Document binaries require a separate encrypted, malware-scanned copy process with MIME/signature verification and private randomized object paths. Missing or unverifiable files remain explicit review items.
