#!/usr/bin/env bash
set -euo pipefail
target="${1:?usage: backup-staging.sh TARGET_DIRECTORY}"
db_url="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
api_url="${NEXT_PUBLIC_SUPABASE_URL:-http://127.0.0.1:54321}"
case "$db_url $api_url" in *127.0.0.1*|*localhost*) ;; *) test "${VEERA_BACKUP_ACK:-}" = isolated-staging-synthetic || { echo 'Refusing non-local backup without isolated staging acknowledgement' >&2; exit 2; };; esac
mkdir -p "$target"
chmod 700 "$target"
if command -v pg_dump >/dev/null 2>&1; then
  pg_dump --format=custom --no-owner --no-privileges --dbname="$db_url" --file="$target/database.dump"
elif [[ "$db_url" == *127.0.0.1* || "$db_url" == *localhost* ]]; then
  docker exec "${SUPABASE_DB_CONTAINER:-supabase_db_veera-v2-local}" pg_dump --format=custom --no-owner --no-privileges --username=postgres --dbname=postgres > "$target/database.dump"
else
  echo 'pg_dump is required for a remote isolated staging backup' >&2; exit 2
fi
sha256sum "$target/database.dump" > "$target/SHA256SUMS"
printf '%s\n' "created_at=$(date -u +%FT%TZ)" "api_origin=$api_url" "storage=provider-export-required-until-reviewed-adapter" > "$target/manifest.txt"
chmod 600 "$target"/*
echo "Database backup created. Private Storage export remains a provider-level step; see runbook."
