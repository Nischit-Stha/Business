# Contributing

## Workflow

1. Create a feature branch.
2. Keep changes scoped and small.
3. Add/update tests for changed behavior.
4. Run lint/tests before opening PR.

## Coding Rules

- Keep UI, business logic, and data-access separated.
- Put Supabase calls in service modules.
- Keep shared validation logic in one place.
- Avoid hardcoded secrets in frontend files.

## Required Checks

- HTML/CSS/JS linting
- validation/unit tests for changed validators
- flow tests for pickup/dropoff/swap when changed
