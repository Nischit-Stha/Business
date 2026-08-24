# Local and staging schedule extension

The schedule extender is deliberately not connected to production.

Run `public.run_open_agreement_schedule_extension(12)` once daily from a local or staging scheduler using a dedicated active `ADMIN` account and its authenticated JWT. The RPC accepts only an 8–12 week horizon, scans only active agreements with no end date, and calls the existing idempotent schedule generator. Completed, cancelled, suspended, bounded, draft, and pending-signature agreements are ignored.

Safe local smoke test:

```sql
select * from public.run_open_agreement_schedule_extension(12);
```

The call is safe to retry. Unique agreement/sequence and agreement/due-date constraints prevent duplicates. Each agreement runs in its own exception block; one failure does not stop the remainder. Failures create or refresh one owner-only `SCHEDULE_EXTENSION_FAILURE` exception per agreement. Successful execution is audited but does not enter the attention queue.

For staging, configure the scheduler outside source control and store its JWT in the staging platform's secret manager. Use HTTPS, least-privilege network access, and a dedicated account that can be disabled independently. Do not add a production cron entry, service-role key, database password, or token to this repository.
