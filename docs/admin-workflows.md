# Admin Workflows

## Staff provisioning

There is no public signup route. Provision staff in two controlled steps:

1. An authorized administrator creates the user in Supabase Auth using the dashboard or a secured server-side admin tool. Never expose the service-role key to the web app.
2. For the first administrator only, a database owner inserts the matching profile during an approved local/staging operation:

   ```sql
   insert into public.staff_profiles (user_id, full_name, role, status, is_active)
   values ('AUTH-USER-UUID', 'Staff display name', 'ADMIN', 'ACTIVE', true);
   ```

After bootstrap, an active `ADMIN` calls `public.set_staff_access(user_id, full_name, role, status)` from a secured admin tool. It accepts roles `ADMIN` and `STAFF`, statuses `ACTIVE` and `DISABLED`, synchronizes the legacy `is_active` flag, and writes `STAFF_ACCESS_CHANGED` audit events. Disabling a profile immediately removes staff authorization even if its Auth session remains valid. Role and status are never read from Auth user metadata.

Do not provision production until the separately reviewed production migration/runbook task.

## Pickup

1. Customer submits pickup request.
2. Request enters `submitted`.
3. Admin reviews and moves to `under_review` / `approved`.
4. Vehicle + customer records are linked and tracked.

## Drop-off

1. Staff/customer identifies rental by rego + contact info.
2. Odometer/photos captured.
3. Admin marks completion and finalizes invoice state.

## Swap

1. Existing booking identified.
2. Swap event logged in request history.
3. Admin reassigns vehicle and updates status chain.

## Audit Expectations

All admin mutations should stamp:

- `updated_at`
- `last_modified_by`
