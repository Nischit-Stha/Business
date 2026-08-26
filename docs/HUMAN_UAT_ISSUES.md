# Veera V2 human workflow UAT audit

Audit date: 26 August 2026 (Australia/Melbourne)

Scope: owner, staff, and customer workflows in the local staging-equivalent V2 application. Only synthetic accounts and records were used. No production system, production credential, external provider, or real customer data was accessed. This is a human and operational review, not an authorization or penetration-test sign-off.

Method: exercised the synthetic owner/admin and customer journeys in the browser at desktop and representative mobile widths; ran the existing 25-test Playwright trial suite; reviewed the rendered controls, navigation, empty/error states, and server actions behind the 22 requested workflows. The existing suite passed 25/25, which confirms route availability, basic role isolation, labelling, keyboard focus, and lack of horizontal page overflow. It does not invalidate the human workflow issues below.

No application behavior was changed during this audit.

## Fix sprint 1 status — 26 August 2026

Implemented in the forward-only `20260826020000_human_uat_fix_sprint_1.sql` migration and associated web changes:

- **FIXED:** HUAT-001, HUAT-002, HUAT-006, HUAT-008, HUAT-013, HUAT-017, HUAT-019, HUAT-023, HUAT-027 (for touched workflows), and HUAT-028 (for touched workflows).
- **PARTIALLY FIXED:** HUAT-007 (planned-vehicle wording/options), HUAT-016 (Today links and mobile presentation), HUAT-020 (one primary engine, but notification policy/settings remain open), and HUAT-024 (admin account navigation only; wider role matrix remains open).
- **OPEN — VEERA DECISION:** All other issues and every policy-dependent portion explicitly identified below remain open. No referral, payment, collections, breakdown policy, reminder cadence, legal-transfer policy, document SLA, or reporting behavior was changed.

Exact sprint fixes:

1. Portal access uses an idempotent audited database function, retains account relationships, writes security/audit history, bans/unbans Auth safely, rolls Auth state back when the relational update fails, and shows explicit success/recoverable failure text. The invalid user-ID-as-JWT sign-out call was removed.
2. Direct assignment can no longer create custody. Agreement plus pickup scheduling is the planned state; the custody row and `ASSIGNED` vehicle state begin atomically at confirmed handover.
3. Pickup cards show customer, vehicle, agreement, scheduled time, actual time input, odometer, visible issues, document/approval state, compliance, maintenance, blockers, and required keys/vehicle confirmation.
4. Return disposition is derived server-side. Active maintenance routes to Workshop; condition, issue, agreement, compliance, or overdue-service blockers route Off road; only a fully clear car becomes Available.
5. Notifications is the sole navigation workflow. Legacy Messaging is read-only and points staff to Notifications.
6. Today now shows prioritised named records, urgency, required action, and a direct link for the eight requested work categories.
7. Compliance is grouped into blocking/warning/valid cards with search, plain-language status, prominent expiry, and collapsed edit controls; underlying rules were not changed.

## Executive result

The product contains the core records and controls needed for a trial, but it does not yet guide a person safely through several end-to-end jobs. The largest operational risk is that assignment, agreement, pickup, payment, and return are presented as separate controls without a single, obvious next-action path. The system often exposes internal status codes and implementation concepts, while leaving staff to remember the real-world handoff and customer communication.

The known portal revoke defect was reproduced as part of the controlled synthetic-account check: after active portal access is revoked, the customer experience falls into the generic error state, **“We couldn't load this. Something went wrong.”** It does not reliably reach the purpose-built “Portal access unavailable” explanation. The administration side can also return a generic “Unable to change access” result even when account state may already have changed, so the operator cannot confidently tell whether recovery is required. The synthetic account was checked after the test and left ACTIVE and unbanned.

## Top 10 human and operational problems, ranked by business impact

| Rank | Issue | Business impact | Disposition |
|---:|---|---|---|
| 1 | HUAT-001 — revoked portal session crashes into a generic error | Customers cannot understand why access disappeared and will call Veera; staff cannot confidently verify the result | Clear bug — fix now |
| 2 | HUAT-006 — assignment records pickup custody before the pickup workflow | Custody, odometer, vehicle state, and agreement timing can disagree | Workflow choice — Veera confirmation |
| 3 | HUAT-010 — two payment-entry paths create an unclear source of truth | A receipt can be entered manually and later imported/reconciled, increasing duplicate-allocation risk | Workflow choice — Veera confirmation |
| 4 | HUAT-008 — pickup can be completed with almost no handover evidence | Staff can release a car without a visible checklist, signature, document, key, fuel, or condition confirmation | Workflow choice — Veera confirmation |
| 5 | HUAT-013 — return choices allow unsafe or contradictory outcomes | A damaged/unsafe vehicle can be released through one compact form with no confirmation | Clear safety bug plus policy confirmation |
| 6 | HUAT-004 — approval queue hides evidence and lacks a guided readiness decision | Owner approval is reduced to status codes and a free-text note, causing rework or unsafe approval | Clear usability bug; approval policy needs confirmation |
| 7 | HUAT-019 — notification and messaging are duplicate operator consoles | Staff cannot know which queue is authoritative, so reminders may be missed or duplicated | Workflow choice — Veera confirmation |
| 8 | HUAT-003 — onboarding does not record referral or preserve the onboarding handoff | Veera cannot operate or report the referred-customer process without notes/memory outside the system | Workflow choice — Veera confirmation |
| 9 | HUAT-017 — compliance is a 150-row raw update grid with manual status entry | Expiry decisions are error-prone and routine compliance work becomes slow | Clear usability bug; status policy needs confirmation |
| 10 | HUAT-023 — Today shows counts, not a workable ordered task list | Staff still have to open multiple pages and reconstruct priority, owner decision, and next action | Clear usability gap; prioritisation needs confirmation |

## Detailed issue register

### HUAT-001 — Portal revoke reaches generic failure

- **Status:** FIXED in Human UAT Fix Sprint 1. Root cause and exact fix are recorded above.

- **Page/workflow:** Account access → customer portal access revoke; customer portal
- **Role:** Admin/owner and customer
- **Severity:** HIGH
- **Observed behavior:** Revoking an active synthetic customer's portal access causes the customer's active portal experience to show “We couldn't load this. Something went wrong.” The intended “Portal access unavailable” page is not reliably reached. During the controlled check, the admin action could also report “Unable to change access,” leaving the final state ambiguous.
- **Expected human behavior:** The admin sees an explicit confirmation naming the customer and effective time. The customer's next request lands on a calm access-revoked page with a sign-out option and Veera contact path.
- **Why it matters operationally:** Customers interpret the result as an outage and call Veera. Staff may retry a sensitive action or be unable to tell whether the customer is still signed in.
- **Recommended fix:** Make revoke idempotent; complete account-state change and global sign-out with an auditable result; treat an invalidated customer session as access denied rather than an application error; show a customer-safe reason and an admin-side final-state confirmation.
- **Business confirmation required:** No for the error/confirmation fix. Yes only for the exact customer contact wording.

### HUAT-002 — Account access is not discoverable from navigation

- **Status:** FIXED in Human UAT Fix Sprint 1. Administrators now see Account access in Management; normal staff do not.

- **Page/workflow:** Staff/admin provisioning and portal access enable/revoke
- **Role:** Admin/owner
- **Severity:** HIGH
- **Observed behavior:** “Account access” exists at `/admin/accounts`, but the staff navigation has no link to it. The page is reachable only by knowing the URL or an undocumented route.
- **Expected human behavior:** An admin can find “Team & portal access” under a clearly owner/admin-only area.
- **Why it matters operationally:** Provisioning and urgent revocation are time-sensitive. A hidden route creates support dependency and encourages credential sharing or delayed removal.
- **Recommended fix:** Add an admin-only navigation group/link and show it only to administrators; do not expose the route to ordinary staff as an actionable destination.
- **Business confirmation required:** No.

### HUAT-003 — Referred-customer onboarding has no referral workflow

- **Page/workflow:** New referred customer onboarding
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** “New customer” collects name, phone, email, licence number/expiry, and address. It does not capture referral source/referrer, consent/contact preference, onboarding owner, received date, or the next required step. After creation there is no visible onboarding checklist or referral acknowledgement.
- **Expected human behavior:** Staff record the minimum referral context once, see what is still needed, and hand the customer into approval without maintaining a separate note or remembering whom to contact.
- **Why it matters operationally:** Referral attribution is lost, follow-up is inconsistent, and Veera must reconstruct context through calls or messages.
- **Recommended fix:** Add a small onboarding context section and a post-create next-action panel linking to document request/review and approval. Avoid adding fields until Veera confirms which referral details are operationally necessary.
- **Business confirmation required:** Yes.

### HUAT-004 — Approval decision is detached from evidence

- **Page/workflow:** Approval queue & readiness
- **Role:** Admin/owner
- **Severity:** HIGH
- **Observed behavior:** The queue shows raw values such as `APPROVED`, `VERIFIED`, `BLOCKED`, and `YES/NO`. The owner can select APPROVED/REJECTED/SUSPENDED and enter optional notes directly in a dense row, but cannot open the customer or view the licence/address evidence from that decision cell.
- **Expected human behavior:** The owner reviews a concise evidence summary, opens the relevant document when necessary, sees explicit blockers, records a required reason for rejection/suspension, and then decides.
- **Why it matters operationally:** Approval becomes a memory-based status change rather than an informed business decision. Incorrect approval can expose vehicles, insurance, and revenue.
- **Recommended fix:** Link the customer and documents, translate statuses into plain language, show blockers, require a reason for adverse decisions, and add a confirmation for suspension/rejection.
- **Business confirmation required:** Yes for the evidence and decision policy; no for links and plain-language labels.

### HUAT-005 — Customer status and approval status look like competing decisions

- **Page/workflow:** Customer detail; approval queue
- **Role:** Staff and admin/owner
- **Severity:** MEDIUM
- **Observed behavior:** Customer detail offers ACTIVE/INACTIVE/BLOCKED, while the approval queue offers APPROVED/REJECTED/SUSPENDED. Their relationship and operational effect are not explained, and both use direct status selectors.
- **Expected human behavior:** Staff understand whether a person is onboarded, approved to rent, temporarily paused, or denied, and which action changes each state.
- **Why it matters operationally:** Staff can set apparently contradictory states and may call Veera to ask whether a customer is actually eligible.
- **Recommended fix:** Present a single human-readable readiness summary and explain the separate meanings of account/contact status and rental approval. Limit each role to the decision it owns.
- **Business confirmation required:** Yes.

### HUAT-006 — Assignment and pickup both claim the custody handoff

- **Status:** FIXED in Human UAT Fix Sprint 1 under the explicit sprint direction. Planning and physical custody are separate states.

- **Page/workflow:** Vehicle availability and assignment; agreement creation; pickup
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** “Assign vehicle” asks for a **Pickup odometer** and immediately changes assignment/custody state. A separate pickup page later asks for pickup kilometres again and completes a checklist. Agreement creation, however, expects a matching active assignment before agreement activation. The human sequence is circular and duplicated.
- **Expected human behavior:** Staff reserve/select a ready vehicle, prepare and sign the agreement, then complete one physical pickup that records custody and odometer exactly once.
- **Why it matters operationally:** The database can say a customer has custody before keys are handed over, and two odometer entries can conflict. Insurance, toll, fine, and damage attribution depend on correct custody time.
- **Recommended fix:** Decide and label distinct states such as Reserved → Agreement ready/signed → Picked up. Record custody and pickup odometer only at the physical handover.
- **Business confirmation required:** Yes.

### HUAT-007 — Agreement form exposes irrelevant and technical fields

- **Status:** PARTIALLY FIXED. Planned-vehicle selection and custody wording are corrected. Conditional commercial fields/defaults remain OPEN for Veera confirmation.

- **Page/workflow:** Agreement creation
- **Role:** Staff
- **Severity:** MEDIUM
- **Observed behavior:** The form always shows RTO total/payment count and “External provider / External contract ID,” including for weekly rental. Type options are database codes (`WEEKLY_RENTAL`, `RENT_TO_OWN`, `SHORT_TERM`). Customer and assigned vehicle are independent selectors, so incompatible choices can be made and rejected only later.
- **Expected human behavior:** Staff choose a plain-language agreement type, see only relevant fields, and see only the selected customer's eligible assigned/reserved vehicle.
- **Why it matters operationally:** Unnecessary choices increase entry errors and make staff feel they need technical knowledge of integrations.
- **Recommended fix:** Use conditional fields, plain-language labels, filtered vehicle choices, safe defaults, and an inline explanation of why activation is blocked.
- **Business confirmation required:** No for conditional display/labels/filtering; yes for agreement defaults.

### HUAT-008 — Pickup completion is not a meaningful checklist

- **Status:** FIXED for the existing-data checklist requested in Human UAT Fix Sprint 1. Fuel/photo features were not invented.

- **Page/workflow:** Pickup
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** Each pickup is a table row with one odometer field and “Complete pickup.” Readiness blockers are text only. There are no visible confirmations for identity/licence, signed agreement, vehicle condition/photos, fuel, keys, customer orientation, or acknowledgement. The action has no confirmation or recovery affordance.
- **Expected human behavior:** Staff follow a short, auditable handover checklist, cannot complete while blocked, and can correct a mistaken odometer through a controlled path.
- **Why it matters operationally:** A single click represents a high-liability physical handover without enough evidence or mistake prevention.
- **Recommended fix:** Add a focused pickup detail/checklist screen with hard blockers, required confirmations, a final summary, and a controlled correction flow.
- **Business confirmation required:** Yes, for the required handover checklist and evidence.

### HUAT-009 — Payments page has no obvious “payment received” action

- **Page/workflow:** Normal weekly payment and overdue weekly payment
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** Payments rows show amounts, status, and reminder state, but the only row action is “View.” Manual receipt entry is buried on the agreement detail page under “Record PayID payment.” The payments page does not show the received reference or a clear reconciliation state.
- **Expected human behavior:** From the payment queue, staff can see whether money is merely reported, imported, matched, or posted, and take the one appropriate next action.
- **Why it matters operationally:** Routine payments require extra navigation and institutional knowledge; staff may wrongly mark money received before verifying the bank record.
- **Recommended fix:** Add a clear next-action link such as “Review receipt” or “Record verified manual receipt,” with source/status wording that matches the ledger.
- **Business confirmation required:** Yes for when manual entry is allowed; no for clearer status and navigation.

### HUAT-010 — Manual payment and bank reconciliation have no declared source of truth

- **Page/workflow:** Normal payment; payment reconciliation
- **Role:** Staff and owner
- **Severity:** HIGH
- **Observed behavior:** Agreement detail can directly “Record verified payment,” while reconciliation can later allocate an imported receipt. The UI does not warn about duplicate entry or explain when each route should be used.
- **Expected human behavior:** Staff use one primary receipt path; exceptional manual entries require a clear reason and are visibly checked against imports.
- **Why it matters operationally:** Duplicate receipts or allocations distort overdue balances, RTO progress, and reports.
- **Recommended fix:** Define the authoritative payment-ingestion workflow, add duplicate detection/context, and label manual entry as an exception if that is Veera's policy.
- **Business confirmation required:** Yes.

### HUAT-011 — Overdue work has no integrated contact or promise action

- **Page/workflow:** Overdue weekly payment; collections
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** An overdue row shows amount, days overdue, and reminder state, then only “View.” Staff must navigate elsewhere to find contact details, log a call, create a promise, or understand the reminder already sent. “Collections” is a separate navigation destination and the connection is not explained.
- **Expected human behavior:** Staff see contact preference, last reminder/contact, promise status, owner escalation threshold, and a safe next action in one case view.
- **Why it matters operationally:** The system still makes staff reconstruct the story and call Veera for policy decisions; duplicate or inappropriate contact becomes more likely.
- **Recommended fix:** Link overdue rows to a unified collection case timeline with “contact,” “record outcome,” and “promise” actions, while keeping owner-only escalation decisions separate.
- **Business confirmation required:** Yes.

### HUAT-012 — Reconciliation detail is written for developers/accountants, not routine staff

- **Page/workflow:** Payment reconciliation
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** The page exposes “Raw imported values” as JSON, UUID agreement identifiers, numeric matching scores, “actor reason,” three always-visible split slots, “Post reconciliation,” and raw allocation JSON. Ignore and reverse actions sit beside normal actions without a confirmation step.
- **Expected human behavior:** Staff see payer, date, amount, suggested customer/agreement, why it matched in plain language, outstanding weeks, and one safe confirm/change/split decision. Technical evidence can be placed under “Advanced details.”
- **Why it matters operationally:** Cognitive load makes a financially sensitive task slow and error-prone. Raw identifiers do not help a person decide.
- **Recommended fix:** Redesign presentation only: progressive disclosure, customer/vehicle/agreement labels, calculated split remainder, confirmation summary, and explicit irreversible/compensating-entry language.
- **Business confirmation required:** No for presentation; yes for who may ignore/reverse and matching thresholds.

### HUAT-013 — Return form permits contradictory and dangerous choices

- **Status:** FIXED. Staff no longer choose a contradictory disposition; the database derives a blocker-safe state.

- **Page/workflow:** Vehicle return
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** One form combines return kilometres, GOOD/DAMAGE_NOTED/UNSAFE, an unlabelled “Open issue” checkbox, and RELEASE/WORKSHOP/OFF_ROAD. The UI does not prevent “UNSAFE + RELEASE,” does not collect damage detail/photos, and does not show a final confirmation.
- **Expected human behavior:** Unsafe or damaged results force an issue and non-release disposition; staff capture condition evidence and confirm the custody end time.
- **Why it matters operationally:** A vehicle can be shown as available despite a safety problem, and liability evidence is incomplete.
- **Recommended fix:** Add compatible-choice validation immediately, replace the checkbox with a guided issue step, show a summary before completion, and provide a controlled correction process.
- **Business confirmation required:** No for preventing unsafe release; yes for required return evidence and disposition policy.

### HUAT-014 — Breakdown reporting does not guide emergency response or customer contact

- **Page/workflow:** Vehicle issue/breakdown
- **Role:** Customer and staff
- **Severity:** HIGH
- **Observed behavior:** The customer form advises emergency services for immediate danger, but provides no Veera phone/contact button, roadside-assistance instruction, location, drivable/tow-needed question, or expected response. Staff see four parallel cards (assign, update, note, resolve) and raw status options.
- **Expected human behavior:** The customer knows what to do now and how Veera will respond. Staff receive the minimum triage facts, assign ownership, and communicate the next update.
- **Why it matters operationally:** Breakdowns are stressful, time-sensitive exceptions. Missing guidance directly creates calls and safety uncertainty.
- **Recommended fix:** Add approved emergency/roadside contact guidance and structured triage fields; make the staff page show the next recommended action and last customer update.
- **Business confirmation required:** Yes for contact/escalation policy and triage questions.

### HUAT-015 — Issue statuses differ between staff and customer without an explained mapping

- **Page/workflow:** Vehicle issue/breakdown; customer portal
- **Role:** Staff and customer
- **Severity:** MEDIUM
- **Observed behavior:** Staff use statuses including `WAITING_CUSTOMER` and `WAITING_PARTS`; the portal uses a different `customer_status` vocabulary such as “Being reviewed” and “Waiting.” Notification type selectors expose codes such as `ISSUE_STATUS_UPDATE`.
- **Expected human behavior:** Staff understand exactly what the customer sees and whether a status change sends an update.
- **Why it matters operationally:** Staff can tell a customer one state while the portal shows another, generating clarification calls.
- **Recommended fix:** Display the customer-visible wording beside staff status actions and replace notification codes with sentences describing the message.
- **Business confirmation required:** Yes for the mapping and auto-notify rules; no for showing the mapping.

### HUAT-016 — Maintenance page mixes planning, configuration, execution, and history

- **Status:** PARTIALLY FIXED. Today provides direct prioritised service work and mobile-safe links. Maintenance configuration/work ownership choices remain OPEN.

- **Page/workflow:** Maintenance/service
- **Role:** Staff and owner
- **Severity:** MEDIUM
- **Observed behavior:** “Schedule work” and “Service interval override” appear together above overdue, due-soon, workshop, scheduled, and full completed-history sections. With the scaled synthetic fleet, vehicle selectors and tables are long. Scheduled work has no visible reschedule/cancel action, supplier, booking time, or responsible staff member.
- **Expected human behavior:** Staff work from an ordered due queue, create a booking with owner/date/workshop, then start and complete it; rare interval configuration is separated and owner-controlled if appropriate.
- **Why it matters operationally:** Routine jobs are buried in a high-load page and staff must remember booking details elsewhere.
- **Recommended fix:** Split configuration from daily work, add filters/search, provide job detail/reschedule/cancel/assignee controls, and keep service history collapsed or paginated.
- **Business confirmation required:** Yes for ownership, supplier, and interval permissions; no for information architecture and filtering.

### HUAT-017 — Compliance grid requires manual status calculation and raw code handling

- **Status:** FIXED for UX risk reduction. Rules remain unchanged; grouped cards, plain wording, expiry visibility, search, and collapsed edits replace the dense grid.

- **Page/workflow:** Rego/RWC/licence compliance
- **Role:** Staff and owner
- **Severity:** HIGH
- **Observed behavior:** Vehicle compliance renders every vehicle in a table with code-like statuses and an update form in each row. Staff choose VALID/EXPIRING_SOON/EXPIRED/MISSING manually even though issue/expiry dates are entered. There is no evidence link, renewal workflow, owner, reminder state, or safe handling for “no expiry.” Customer licence status is managed separately in another dense table.
- **Expected human behavior:** The system calculates exposure from trusted dates/evidence, shows an ordered expiry queue, assigns renewal/review ownership, and prevents allocation when required.
- **Why it matters operationally:** Manual derived status can contradict dates, and expiring rego/RWC/licences can be missed across a large fleet.
- **Recommended fix:** Calculate status from dates and verification state, provide filters and a compliance case view linked to documents, and unify the presentation of customer and vehicle compliance queues.
- **Business confirmation required:** Yes for warning windows and evidence policy; no for derived-status consistency and links.

### HUAT-018 — Toll/fine review exposes internal matching language and weakens the legal decision

- **Page/workflow:** Toll/fine handling
- **Role:** Staff and owner
- **Severity:** HIGH
- **Observed behavior:** The main page uses status codes, confidence values, “provider-neutral internal matching,” and both synthetic import and manual entry above the work queues. The review relies on match evidence but routine staff are not clearly separated from the legal transfer confirmation decision. Parallel `/tolls-fines` and `/operations/tolls-fines` route families also make the canonical workflow unclear.
- **Expected human behavior:** Staff import/capture the notice and review custody evidence; an explicitly authorised role confirms or disputes liability transfer with a clear deadline and audit note.
- **Why it matters operationally:** A legal/financial action can be mistaken for a normal matching task, while duplicate destinations increase the chance of using the wrong screen.
- **Recommended fix:** Establish one canonical route, hide staging/import explanation under advanced tools, use plain-language evidence, and visually separate “suggested match” from “confirm legal transfer.”
- **Business confirmation required:** Yes for decision authority and legal process; no for canonical navigation and terminology.

### HUAT-019 — Notifications and Messaging duplicate the same operational job

- **Status:** FIXED. Durable Notifications is primary; legacy Messaging is retained read-only and clearly deprecated.

- **Page/workflow:** Notification/reminder workflow
- **Role:** Staff and owner
- **Severity:** HIGH
- **Observed behavior:** “Notifications” and the unlinked “Messaging” page both offer “Generate reminders,” worker controls, delivery queues, retry, and cancel. One uses notification types/statuses and the other template/provider terminology. The operator cannot tell which system actually communicates with customers.
- **Expected human behavior:** Staff have one reminder/communication operations view and one understandable delivery state for each customer message.
- **Why it matters operationally:** Duplicate consoles invite duplicate sends, missed retries, conflicting audit trails, and reliance on technical staff.
- **Recommended fix:** Choose one operator-facing workflow and make the other an internal delivery detail or retire it after migration. Do not merge behavior until Veera confirms the intended channel/process.
- **Business confirmation required:** Yes.

### HUAT-020 — Reminder settings and worker controls are too technical and too exposed

- **Status:** PARTIALLY FIXED. Duplicate workflow ambiguity is removed. Role/cadence/configuration policy remains OPEN for Veera confirmation.

- **Page/workflow:** Notification/reminder workflow
- **Role:** Staff and admin/owner
- **Severity:** HIGH
- **Observed behavior:** The same page used for daily notification review exposes comma-separated timing arrays, maximum retries, “Generate due reminders,” “Run local worker,” “Record local receipt,” and status codes. These controls are not visibly owner/admin-only.
- **Expected human behavior:** Normal staff review exceptions and customer history. An authorised administrator configures policy through understandable fields; scheduled delivery runs without a human pressing worker buttons.
- **Why it matters operationally:** Routine staff can accidentally change business-wide contact cadence or believe they must manually run automation.
- **Recommended fix:** Separate configuration and diagnostic controls into an admin-only area, replace comma-separated inputs with labelled stages, and show whether automation is healthy/running.
- **Business confirmation required:** Yes for reminder cadence and roles; no for access separation and plain-language controls.

### HUAT-021 — Portal document replacement can obscure the current reviewed version

- **Page/workflow:** Customer document upload/review
- **Role:** Customer and staff
- **Severity:** MEDIUM
- **Observed behavior:** The portal finds the first record by document type and offers “Upload replacement,” but does not explain whether the verified document remains valid while the replacement is under review. Statuses are uppercase, dates are raw ISO values, and there is no visible expected review time or contact path after rejection.
- **Expected human behavior:** Customers know which version is current, what is awaiting review, whether they can keep driving/renting, why a file was rejected, and when to expect review.
- **Why it matters operationally:** Uncertainty creates document-status calls and may cause unnecessary service interruption.
- **Recommended fix:** Show current vs submitted version, customer-safe rejection reason, review expectation, friendly dates/statuses, and a clear “need help?” contact action.
- **Business confirmation required:** Yes for service-impact and review-time promises; no for version/status clarity.

### HUAT-022 — Portal requests lack acknowledgement ownership and a confirmed outcome

- **Page/workflow:** Portal schedule/contact requests
- **Role:** Customer and staff
- **Severity:** MEDIUM
- **Observed behavior:** Customers receive only “Your request was sent.” Schedule changes say Veera will confirm, but no expected response time or urgent contact path is provided. Contact change and general request share one page; staff request handling is a separate queue with code-like request types/statuses.
- **Expected human behavior:** Customers see “received,” who/when will respond, the original request, and a final confirmed appointment/contact value. Staff see owner, age/SLA, and one clear respond/complete path.
- **Why it matters operationally:** Customers may assume a requested pickup/return time is confirmed or call Veera to chase it.
- **Recommended fix:** Distinguish Requested from Confirmed prominently, add a customer-visible response/outcome, age/owner in the staff queue, and approved urgent-contact guidance.
- **Business confirmation required:** Yes for response commitments and urgent contact rules; no for requested-vs-confirmed clarity.

### HUAT-023 — Today is a count dashboard, not a daily work list

- **Status:** FIXED for the requested priority queues. Today now identifies the event, person/vehicle, urgency, next action, and destination.

- **Page/workflow:** Owner Today/dashboard workflow
- **Role:** Staff
- **Severity:** HIGH
- **Observed behavior:** Today presents ten clickable counts. It does not name the customers/vehicles, order tasks by time/risk, show ownership, mark completion, or distinguish work staff can do from decisions requiring Veera/admin. The owner dashboard separately has an attention queue, producing two concepts of “today.”
- **Expected human behavior:** Staff open one ordered list, see the next action and due time, complete routine work, and escalate owner-only decisions. The owner sees only exceptions and approvals.
- **Why it matters operationally:** Staff must visit many pages, remember what they already handled, and ask Veera which item matters first.
- **Recommended fix:** Turn Today into a role-aware task list backed by existing records; define the owner dashboard as the exception/decision view and cross-link without duplicating work.
- **Business confirmation required:** Yes for priority and ownership rules; no for showing named actionable items.

### HUAT-024 — Owner-only decisions are inconsistently separated

- **Status:** PARTIALLY FIXED. Account access is now consistently admin-only in navigation. The broader role/action matrix remains OPEN for Veera confirmation.

- **Page/workflow:** Approval, reconciliation, toll/fine, notification settings, reports, account provisioning
- **Role:** Staff and admin/owner
- **Severity:** HIGH
- **Observed behavior:** Approval correctly says “Veera/admin only” for staff, but other high-impact controls are mixed into shared pages. Navigation does not visually identify owner-only destinations, while Account access is hidden entirely. Reports and financial/reconciliation pages are available through the normal staff navigation.
- **Expected human behavior:** Staff can clearly see what they may prepare or recommend; owner/admin-only decisions are labelled, permission-controlled, and grouped consistently.
- **Why it matters operationally:** Staff either avoid legitimate work because authority is unclear or perform decisions Veera intended to retain.
- **Recommended fix:** Create a consistent role/action matrix in the UI, label owner decisions, and hide or disable only the decision controls—not the operational evidence staff need.
- **Business confirmation required:** Yes.

### HUAT-025 — Rent-to-own completion is safe but progress is not actionable

- **Page/workflow:** Rent-to-own progress/completion
- **Role:** Customer, staff, and admin/owner
- **Severity:** MEDIUM
- **Observed behavior:** The agreement detail correctly separates payment completion from external legal transfer confirmation. However, the customer portal shows counts/balance without an estimated completion date, explanation of corrections/arrears, or next step at schedule completion. The admin form uses “external transfer reference” without explaining acceptable evidence, and completion remains one of several raw lifecycle options.
- **Expected human behavior:** Customer and staff understand payments remaining and the non-binding estimated finish; once paid, the owner sees a distinct checklist for external transfer evidence before completion.
- **Why it matters operationally:** Customers will call to ask “when is the car mine?”, and staff may treat payment completion as legal transfer.
- **Recommended fix:** Add customer-safe explanatory progress and a separate owner completion checklist. Preserve the existing rule that the system does not perform legal transfer.
- **Business confirmation required:** Yes for estimate wording, evidence, and transfer process; no for separating the completion action visually.

### HUAT-026 — Reports cannot answer common management follow-up questions

- **Page/workflow:** Reports
- **Role:** Owner/admin
- **Severity:** MEDIUM
- **Observed behavior:** Reports show a fixed current snapshot for fleet, this-week finance, maintenance/customers, and operations. There are no date controls, definitions/as-of time, trends, drill-downs, export, or reconciliation completeness indicator.
- **Expected human behavior:** Veera can understand the period and data freshness, click a total to inspect its records, and export an agreed operational/financial report when required.
- **Why it matters operationally:** A total that cannot be explained or traced sends the owner back to spreadsheets or technical support.
- **Recommended fix:** First add definitions, “as of” time, and drill-down links. Confirm the small set of reports/periods/exports Veera actually needs before adding broader reporting.
- **Business confirmation required:** Yes for report catalogue and export formats; no for freshness and drill-down transparency.

### HUAT-027 — Success and error feedback is generic across high-impact actions

- **Status:** FIXED for account access, pickup, return, and compliance. Cross-cutting untouched workflows remain OPEN.

- **Page/workflow:** Cross-cutting: accounts, approvals, agreements, payments, pickup/return, compliance
- **Role:** All roles
- **Severity:** MEDIUM
- **Observed behavior:** Errors are commonly passed as a short query-string message and rendered at the top of long pages. Success often depends on redirect/state change with no named outcome. The global fallback says only “We couldn't load this. Something went wrong.” and “Try again.”
- **Expected human behavior:** The message names what succeeded/failed, preserves entered data where safe, explains what changed, and offers the relevant recovery action.
- **Why it matters operationally:** Users retry dangerous actions, lose confidence, or call Veera because they cannot distinguish validation, permission, stale state, and outage errors.
- **Recommended fix:** Introduce action-specific, accessible status summaries; keep safe form input after validation failures; give retry/back/contact choices; include reference IDs only under support details.
- **Business confirmation required:** No, except for customer contact wording.

### HUAT-028 — Mobile technically fits but dense operational tables are not practical

- **Status:** FIXED for Today, pickup, return, and compliance through card/detail layouts. Untouched dense workflows remain OPEN.

- **Page/workflow:** Approval, pickup, compliance, reconciliation, notifications, toll/fine
- **Role:** Staff and owner
- **Severity:** MEDIUM
- **Observed behavior:** Automated checks confirm no page-level horizontal overflow, but large tables use horizontally scrollable wrappers and embed multi-field forms inside cells. At 360–390 px, the user must pan between identity/context and the action, and long selectors contain up to the full scaled fleet/customer list.
- **Expected human behavior:** A staff member on a phone can identify the case, see blockers, and perform a small safe action without horizontal cross-referencing.
- **Why it matters operationally:** Pickups, returns, vehicle issues, and compliance checks frequently happen away from a desk.
- **Recommended fix:** Use responsive cards or a detail/action drawer for priority mobile workflows; add search/autocomplete and keep dangerous multi-field actions on a dedicated page.
- **Business confirmation required:** No.

## Workflow coverage and outcome

| # | Workflow | Human UAT outcome | Primary issues |
|---:|---|---|---|
| 1 | New referred customer onboarding | Core customer creation works; referral and handoff are missing | HUAT-003, HUAT-027 |
| 2 | Customer approval by Veera | Decision exists but evidence and status model are unclear | HUAT-004, HUAT-005 |
| 3 | Vehicle availability and assignment | Availability is visible; reservation/custody meaning is unsafe | HUAT-006 |
| 4 | Agreement creation | Draft/activation separation exists; form is technical and sequence is circular | HUAT-006, HUAT-007 |
| 5 | Pickup | Schedulable/completable; insufficient handover evidence | HUAT-008, HUAT-028 |
| 6 | Normal weekly payment | Amount/status visible; receipt action/source unclear | HUAT-009, HUAT-010 |
| 7 | Overdue weekly payment | Queue visible; collection/contact next step is fragmented | HUAT-011 |
| 8 | Payment reconciliation | Controls exist; excessive technical detail and financial-action risk | HUAT-010, HUAT-012 |
| 9 | Vehicle return | Schedulable/completable; contradictory unsafe outcomes possible | HUAT-013, HUAT-028 |
| 10 | Vehicle issue/breakdown | Report/history work; urgent human response is incomplete | HUAT-014, HUAT-015 |
| 11 | Maintenance/service | Full lifecycle exists; page overload and ownership gaps remain | HUAT-016 |
| 12 | Rego/RWC/licence compliance | Records can be updated; queue and status derivation are weak | HUAT-017, HUAT-028 |
| 13 | Toll/fine handling | Matching/audit concepts exist; legal decision and canonical route are unclear | HUAT-018 |
| 14 | Customer portal | Useful summary; revoke failure and support/contact gaps remain | HUAT-001, HUAT-014 |
| 15 | Customer document upload/review | Secure upload/review path exists; replacement/review state is unclear | HUAT-021 |
| 16 | Portal schedule/contact requests | Requests work; requested vs confirmed and response expectation need clarity | HUAT-022 |
| 17 | Notification/reminder workflow | Queues exist; duplicate consoles and technical/manual controls remain | HUAT-019, HUAT-020 |
| 18 | Rent-to-own progress/completion | Legal transfer separation is good; human progress/completion guidance is incomplete | HUAT-025 |
| 19 | Staff/admin account provisioning | Secure admin control exists; it is hidden and feedback is ambiguous | HUAT-002, HUAT-027 |
| 20 | Portal access enable/revoke | Enable/revoke control exists; revoke error is a trial-blocking customer experience | HUAT-001 |
| 21 | Owner Today/dashboard workflow | Metrics and exceptions exist; staff task execution and role split are unclear | HUAT-023, HUAT-024 |
| 22 | Reports | Snapshot works; definitions, drill-down, periods, and export are missing | HUAT-026 |

## Clear bugs and usability fixes that can start immediately

These changes do not require choosing new business behavior:

1. HUAT-001: route revoked sessions to the access-unavailable page; make the admin result explicit and idempotent.
2. HUAT-002: add an admin-only navigation link to Account access.
3. HUAT-004/HUAT-007/HUAT-015/HUAT-017: replace raw codes with plain-language labels and add links to existing evidence/context.
4. HUAT-007: hide RTO/provider fields when they do not apply and filter assigned vehicles by customer.
5. HUAT-012: place raw JSON, UUIDs, and scoring internals behind advanced details.
6. HUAT-013: prevent an UNSAFE or damaged return from being released.
7. HUAT-017: stop asking staff to manually choose a status that contradicts the entered dates.
8. HUAT-021/HUAT-022: clearly distinguish current/submitted and requested/confirmed states.
9. HUAT-027: add named, action-specific success/error results and safe recovery links.
10. HUAT-028: replace table-cell forms with mobile task/detail views for pickup, return, approval, and compliance.

## Workflow choices that need Veera confirmation before behavior changes

1. What referral information must be recorded and whether referrers receive acknowledgement (HUAT-003).
2. The authoritative onboarding/approval states, required evidence, and who can approve/suspend/reject (HUAT-004–005).
3. The real sequence and meaning of reservation, assignment, signed agreement, custody, and pickup (HUAT-006, HUAT-008).
4. Which agreement defaults and RTO terms staff may enter or change (HUAT-007, HUAT-025).
5. The authoritative weekly-payment source, permitted manual exceptions, duplicate handling, and reconciliation permissions (HUAT-009–012).
6. Required pickup/return evidence, condition choices, and vehicle disposition rules (HUAT-008, HUAT-013).
7. Breakdown escalation, roadside contact, response expectations, and customer-visible issue wording (HUAT-014–015).
8. Maintenance booking ownership/supplier details and who may change service intervals (HUAT-016).
9. Rego/RWC/licence warning windows, acceptable evidence, and renewal ownership (HUAT-017).
10. Who confirms toll/fine liability transfer and the required review evidence/deadlines (HUAT-018).
11. Which notification engine is authoritative, contact cadence, channel preferences, and who controls settings (HUAT-019–020).
12. Document review commitments and whether a pending replacement affects eligibility (HUAT-021).
13. Portal-request response commitments and what constitutes confirmation (HUAT-022).
14. Staff-vs-owner task ownership and the priority order for Today/attention queues (HUAT-023–024).
15. The required management reports, periods, definitions, and export formats (HUAT-026).

## Review stop

This audit intentionally stops before changing business workflow behavior. Veera should review the ranked issues and confirm the choices above before implementation begins. Existing issues have not been hidden or reclassified as fixed merely because the technical smoke suite passes.
