# Staff frontend audit and transformation plan

## Audit summary

The V2 application has strong server-side domain coverage, but its staff UI grew route by route. Every page owns its heading and navigation, the staff navigation is an ungrouped row of more than twenty links, and a single stylesheet mixes staff, portal, table, form, and dashboard concerns. Tables are frequently wider than laptop and tablet viewports, raw enum values appear in customer-facing copy, primary actions compete with secondary administration forms, and empty states vary between `None`, `No data`, and plain paragraphs. Loading boundaries are absent and error messages passed through query strings are visually inconsistent. Operationally important information exists, but readiness, urgency, next movement, and payment exceptions are not consistently prioritized.

## Implementation plan

1. Introduce design tokens and reusable presentation primitives for page headers, metrics, status/severity, filters, cards, tables, feedback states, timelines, summaries, and actions.
2. Replace the flat staff navigation with a responsive application shell: grouped desktop sidebar, mobile navigation, contextual top bar, search, attention entry point, identity, and account controls.
3. Add a server-authorized global search across vehicles, customers, agreements, and issues, returning only operational summary fields.
4. Redesign the owner, fleet, vehicle, customer, payments, handover, issue, maintenance, and notification surfaces around exceptions and next actions while preserving existing actions and queries.
5. Simplify and visually separate the customer portal with mobile-first summaries and customer-safe language.
6. Add route loading/error boundaries, component tests, responsive table/card behavior, and consolidate obsolete CSS only after usage checks.

No database migration is planned: the existing views, RLS policies, server actions, and workflow tables remain the source of truth.
