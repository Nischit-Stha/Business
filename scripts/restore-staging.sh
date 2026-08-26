#!/usr/bin/env bash
set -euo pipefail
source_dir="${1:?usage: restore-staging.sh BACKUP_DIRECTORY}"
db_url="${SUPABASE_RESTORE_DB_URL:-}"
test -n "$db_url" || { echo 'SUPABASE_RESTORE_DB_URL must identify a fresh restore target' >&2; exit 2; }
case "$db_url" in *127.0.0.1*|*localhost*) ;; *) test "${VEERA_BACKUP_ACK:-}" = isolated-staging-synthetic || { echo 'Refusing non-local restore without isolated staging acknowledgement' >&2; exit 2; };; esac
(cd "$source_dir" && sha256sum --check SHA256SUMS)
if command -v pg_restore >/dev/null 2>&1; then
  pg_restore --exit-on-error --no-owner --no-privileges --clean --if-exists --dbname="$db_url" "$source_dir/database.dump"
elif [[ "$db_url" == *127.0.0.1* || "$db_url" == *localhost* ]]; then
  docker exec -i "${SUPABASE_RESTORE_DB_CONTAINER:?set SUPABASE_RESTORE_DB_CONTAINER to a fresh local target}" pg_restore --exit-on-error --no-owner --no-privileges --clean --if-exists --username=postgres --dbname=postgres < "$source_dir/database.dump"
else
  echo 'pg_restore is required for a remote isolated staging restore' >&2; exit 2
fi
echo 'Database restored. Verify schema tests, relationships and private Storage separately per runbook.'
