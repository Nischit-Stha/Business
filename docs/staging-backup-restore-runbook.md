# Staging backup and restore verification

Never run this procedure against production. Use a new isolated restore target and synthetic staging data. The scripts refuse non-local URLs unless `VEERA_BACKUP_ACK=isolated-staging-synthetic` is explicitly set.

## Local executable verification

1. Start/reset local Supabase and run `scripts/backup-staging.sh /tmp/veera-backup-check`.
2. Create a fresh local Supabase instance/project target; do not overwrite the source.
3. Set the fresh target connection variables and run `scripts/restore-staging.sh /tmp/veera-backup-check`.
4. Run database tests, compare manifest row/object counts and checksums, authenticate synthetic staff/customer accounts, and open authorized private documents through the app.
5. Record date, source/target identifiers, migration ID, tool versions, counts, discrepancies, operator and reviewer. Only then set `STAGING_BACKUP_VERIFIED_AT`.

The database archive includes application schemas and Auth relationship tables supported by `pg_dump`; password hashes and Supabase-managed Auth internals may not be portable between managed projects. Storage backup downloads private objects using a server-only service role into an encrypted restricted workspace; restore uses the target service role and preserves bucket/path metadata. Never expose the archive or paths through the web app.

## Provider-level verification still required

Supabase managed PITR/daily backup retention, project-level restore, Auth configuration/identities, encryption keys, Storage object versioning and provider disaster recovery cannot be proven locally. In staging, perform and evidence a provider-supported restore into a separate project, rotate copied secrets, validate Auth-user/profile/customer relationships and private object authorization, then destroy the restore project under the retention policy. Do not claim success from a dashboard setting alone.
