# Deployment Guide

## Pre-Deploy Checklist

- Run lint + tests
- Confirm RLS policies on all exposed tables
- Confirm no service-role key in frontend
- Confirm storage bucket privacy and policies

## Database Change Process

1. Apply migrations in staging first.
2. Run smoke tests for pickup/dropoff/swap/admin.
3. Backup DB before production migration.
4. Apply production migration and verify queries.

## Rollback Plan

- Keep reversible migration scripts.
- Snapshot/back up before each release.
- Roll back app and DB in lockstep.

## Monitoring

- Track JS/runtime errors.
- Track Supabase policy denial errors.
- Alert on failed booking submissions and storage failures.
