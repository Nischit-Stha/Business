# Codex progress

- **Current task:** Veera V2 business core — customers, vehicles, and vehicle assignments
- **Status:** PASS
- **Files created:** `supabase/migrations/20260824010000_business_core.sql`, `supabase/tests/business_core_test.sql`, `apps/web/src/lib/fleet.ts`, `apps/web/src/lib/fleet-actions.ts`, and the Fleet, Customers, and Assignments page files under `apps/web/src/app/`
- **Files modified:** `supabase/seed.sql`, `apps/web/src/app/page.tsx`, `apps/web/src/app/styles.css`
- **Database changes:** Added staff profiles, normalized customers, vehicles, immutable assignment history, audit events, indexes/exclusion constraints, deny-by-default RLS, staff read policies, audit/status triggers, and locked atomic `assign_vehicle_to_customer`, `return_vehicle`, and `swap_vehicle` functions. The bootstrap migration was not changed.
- **Features implemented:** Synthetic local fixtures; fleet/current-customer visibility; customer and assignment-history views; trusted server-side assignment, return, and swap actions; odometer, availability, return-state, and non-overlap enforcement in PostgreSQL.
- **Tests performed:** `npm run lint` PASS; `npm run typecheck` PASS; `npm test` PASS (3); `npm run build` PASS; local `npm run supabase:reset` PASS; `npm exec supabase -- test db` PASS (15); local database lint PASS; `git diff --check` PASS.
- **Unresolved problems or warnings:** No sign-in/staff-provisioning UI is included. Customer/vehicle authoring and pickup/return status-transition workflows are intentionally not included. Agreements, payments, maintenance, tolls/fines, Renta, Starr365, PayID, SMS, production migration, and V1 data migration remain deferred.
- **Security notes:** Authorization uses `staff_profiles`, never user metadata. Operational tables are RLS-protected and authenticated clients have read-only table grants; mutations use staff-checked security-definer functions. No licence images, real PII, production credentials, or production connections were added.
- **Current Git status:** Modified: `apps/web/src/app/page.tsx`, `apps/web/src/app/styles.css`, `supabase/seed.sql`. New/untracked: this progress file, three page directories, two fleet server modules, the business-core migration, and database test directory. No commit created.
- **Recommended next task:** Review this schema/API and then add staff authentication/provisioning plus controlled customer and vehicle management workflows before starting agreements or financial features.
