# Accessibility hardening review

Automation covers representative local synthetic flows and mobile widths but does not establish WCAG certification.

Manual review each of Today, Owner, Fleet, Customers, Payments, Maintenance, Issues, Customer Portal and staff/customer Auth:

- Complete all tasks with keyboard alone; verify logical order, skip/navigation behavior, visible focus, no traps, and focus restoration after dialogs/drawers.
- Test NVDA/Firefox and VoiceOver/Safari: page title, language, landmarks, heading hierarchy, form names/descriptions/errors, table headers, live status, dialog names and state changes.
- Measure text/non-text contrast in default, hover, focus, error, disabled and selected states; do not infer status from colour alone.
- At 320 CSS px and 200%/400% zoom, verify no two-dimensional scrolling except genuine data tables and no obscured focused controls.
- Measure touch targets on a real mobile device; aim for 44×44 CSS px and adequate spacing.
- Test reduced motion, high contrast/forced colours, browser text spacing, timeout/error recovery and authenticator/recovery flows.
- Record browser, assistive technology, viewport, task, evidence, severity, owner and retest result.
