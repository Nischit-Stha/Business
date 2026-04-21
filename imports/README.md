# Current file.xlsx import package

This folder contains cleaned, sorted artifacts generated from `Current file.xlsx`.

## Files
- `current_file_cleaned.csv`: normalized records sorted by `plate`, then `customer_name`
- `current_file_to_supabase.sql`: SQL script to import into Supabase
- `current_file_profile.txt`: quick profile summary (rows, totals, distributions)

## What the SQL does
1. Creates `public.weekly_collection_ledger` (if not exists)
2. Applies admin-only RLS policy for that table
3. Loads cleaned rows into a temp staging table
4. Inserts sorted ledger entries
5. Syncs `public.vehicles` by `plate`
6. Syncs `public.customers` by `full_name`

## Run in Supabase SQL Editor
Open and run:
- `imports/current_file_to_supabase.sql`

## Verify
```sql
SELECT COUNT(*) AS imported_rows
FROM public.weekly_collection_ledger
WHERE source_file = 'Current file.xlsx';

SELECT plate, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day
FROM public.weekly_collection_ledger
ORDER BY plate, customer_name
LIMIT 50;
```
