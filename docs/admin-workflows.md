# Admin Workflows

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
