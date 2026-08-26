# Veera V2 staff operations manual

Use Veera only in the environment named in the trial banner. Never copy real customer information into a development or trial environment.

## Start the day

1. Sign in with your staff account.
2. Open **Today** for pickups, returns, overdue payments, blocked vehicles, approvals and reviews.
3. Open **Dashboard** for owner-level exceptions. Assign an exception when someone owns it; resolve it only with a useful note.

## Customers and approval

- **Customers → Add customer** records the customer. Enter only approved business information.
- **Customer approvals** shows readiness. Verify the driver licence and proof of address, then approve or decline with a reason.
- Use **Request document**/document review when evidence is missing. Do not approve around a blocker.
- Account invitations are sent from **Admin accounts** by an administrator. Disable access immediately when it should stop.

## Allocate a car and create an agreement

1. In **Fleet**, filter **Available**. “Ready for allocation” means the server has passed compliance, service and issue checks.
2. Assign the customer and vehicle. Veera prevents overlapping custody and double assignment.
3. Create the agreement with the stored weekly/deposit/contract terms. Move it through signature to Active only with matching custody.
4. Schedule pickup. Complete it only after readiness checks and the pickup odometer are correct.

For rent-to-own, Veera reports only stored contract terms and allocations. An administrator may complete it only after all scheduled payments are satisfied and external/legal ownership transfer has been independently confirmed and referenced.

## Payments and reconciliation

- **Payments** is the routine queue: Due Today, Overdue, Upcoming and Paid. Each item shows outstanding and reminder state.
- Record a PayID receipt only after independently verifying it. The oldest unpaid obligations are allocated first.
- Use **Reconciliation** for imported synthetic/staged bank exports and ambiguous receipts. Give a reason for manual decisions.
- Never edit or delete a payment. Use **Reverse** with a reason; Veera creates compensating history.
- PayID instructions appear to customers only when an administrator has explicitly approved the business setting.

## Maintenance, issues and movements

- **Maintenance** shows due, overdue and workshop work. Record odometers accurately; they cannot go backwards.
- Schedule/start/complete service with work, cost and notes. Completion recalculates readiness.
- **Vehicle issues** records severity, category, assignee, timeline and resolution. Keep internal notes factual; customers see only safe status.
- Schedule and complete returns with odometer, condition and disposition. Unsafe/open-issue cars go to workshop/off-road, not Available.

## Tolls, fines, documents and requests

- Import only approved synthetic/staging toll/fine files during trial. Review custody evidence. Confirm, override or dispute with a reason; never assume legal liability transfer.
- Documents remain private. Upload PDF/JPEG/PNG only; verify/reject the active version and retain replacement history.
- Portal requests move Submitted → In review → Approved/Declined → Completed. Assign an owner and write a customer-safe response.

## Notifications and automation

- Review queued, sent/delivered, suppressed and failed notifications. Retry only safe temporary failures.
- **Automation** runs only fixed reviewed jobs. Repeated failures belong in owner attention.
- Real email/SMS/WhatsApp must remain off until the staging/production configuration is explicitly approved.
