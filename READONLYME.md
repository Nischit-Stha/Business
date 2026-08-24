# READONLYME — Highly Confidential Product Dossier

**Confidentiality Level:** Highly Confidential  
**Document Purpose:** External company review / partnership / hiring evaluation  
**Project Type:** Full web application (MVP + production-hardening foundation)  
**Prepared On:** 19 April 2026

---

## Confidentiality Notice

This document contains proprietary product, architecture, workflow, and security details for a private web application.

- Share only with approved reviewers for technical due diligence, partnership evaluation, or hiring assessment.
- Do not redistribute, publish, or excerpt without written owner approval.

---

## Ownership Statement

This is **my web application project**, designed and built as a business operations platform with customer-facing and admin-facing workflows.

It includes:
- Product design decisions
- Frontend implementation
- Database/schema integration with Supabase
- Security planning and hardening strategy
- Operational and deployment documentation

---

## Executive Summary

This project is a multi-part business web application focused on operations for two domains:

1. `food/` — public-facing menu site
2. `rentals/frontend/` — Veera Rentals operations app

The rentals system is the primary technical component and supports:
- Customer booking/service requests
- Admin review and operations control
- Fleet and customer data management
- Invoicing and business workflow support

The system currently runs as a static frontend with Supabase-backed data, and includes a security hardening path toward production readiness.

---

## Product Scope

### 1) Public Food Site (`food/`)

- Static HTML/CSS/JS marketing/menu experience
- Separate from rentals domain logic
- Lightweight content-driven experience

### 2) Rentals Operations App (`rentals/frontend/`)

Core operational flows:
- Pickup requests
- Drop-off processing
- Swap request handling
- Admin dashboard operations
- Customer/fleet/invoice visibility

Admin surfaces include:
- Requests tab
- Customers tab
- Fleet tab
- Invoices and reports views

---

## Business Problem Solved

This web app centralizes rental business operations that are often fragmented across spreadsheets, messages, and ad-hoc manual tracking.

It provides a single operational layer for:
- Request intake
- Customer linking
- Fleet state management
- Service events and evidence handling (photos)
- Admin decision workflow
- Financial tracking support

---

## Technical Architecture

### Frontend

- Stack: HTML + CSS + JavaScript
- Hosting model: static hosting or local HTTP server
- UI split across dedicated pages for admin, service, login, and customer actions

### Backend/Data Platform

- Supabase (PostgreSQL + Auth + Storage + policies)
- Data tables include:
  - `vehicles`
  - `booking_requests`
  - `customers`
  - `invoices`
  - `offers`
  - `offer_messages`
  - `payment_intents`

### Security Evolution

Two SQL tracks exist:
- `supabase-setup-final.sql` (MVP compatibility)
- `supabase-security-hardening.sql` (production hardening)

---

## Core User Flows

### Pickup

1. Customer selects vehicle
2. Provides contact + request details
3. Uploads license photos
4. Booking request is created and queued for admin review

### Drop-off

1. Vehicle/customer identified via rego/contact
2. Odometer + photos captured
3. Event/state updated for admin completion and billing progression

### Swap

1. Existing booking context identified
2. Swap request/event captured
3. Admin reassigns and updates operational state

---

## Data Model Strategy

The project intentionally separates concerns:

- `booking_requests`: request/event lifecycle data
- `customers`: profile-level customer information
- `vehicles`: fleet state and operational attributes
- `invoices` and payment-related tables: financial lifecycle support

Planned strict status model for requests:
- `submitted`
- `under_review`
- `approved`
- `completed`
- `rejected`

---

## Security and Privacy Position

### What is now established

- No frontend service-role key usage
- Security documentation and policy framework added
- Production hardening script introduces:
  - deny-by-default RLS
  - admin role checks at DB policy layer
  - audit fields and triggers
  - private storage access model for license photos

### Key privacy objective

License photo and customer data must be protected by policy-driven access controls, never by UI hiding alone.

---

## Validation and Data Integrity

A shared validation layer was introduced for service requests, including:
- Name validation
- Phone validation
- Email validation
- Rego format validation
- Mileage validation
- Request type validation
- Required license upload validation for pickup flow

This reduces inconsistent input handling and creates a reusable validation foundation.

---

## Admin Authorization Direction

The project moved away from frontend-only gatekeeping and now aligns login/access flow with Supabase Auth and role claims.

Target rule:
- Admin actions are authorized by backend/database policy, not just frontend route guards.

---

## Documentation Pack Available

- `README.md` — project overview and setup
- `SECURITY.md` — security model, RLS expectations, secret handling
- `CONTRIBUTING.md` — engineering and workflow conventions
- `docs/data-model.md` — schema boundaries and constraints
- `docs/admin-workflows.md` — operational workflow map
- `docs/deployment.md` — deployment, rollback, and monitoring checklist

---

## Production Readiness Status

### Current state

- Strong MVP foundation
- Production-hardening foundation in place (security baseline + hardening scripts)
- Documentation significantly improved

### Remaining production work

- Full role-driven auth enforcement end-to-end
- Structured test suite (unit + integration + policy tests)
- CI/CD enforcement (lint/test/security checks)
- Monitoring and alerting pipeline
- Backup/restore + migration rollback rehearsals

---

## Suggested Rollout Sequence

1. Security-first finalization
2. DB status and workflow alignment
3. Frontend modular refactor (`services/`, `validation/`, `ui/`, `auth/`, `config/`)
4. Move sensitive admin mutations to backend functions
5. Expand tests and automated checks
6. CI/CD + observability
7. UX improvements on stable foundation

---

## Why This Project Matters

This web application is not a basic demo page; it is an operations-centric product with:
- Business workflow modeling
- Data architecture separation
- Security hardening trajectory
- Administrative process control
- Extensible production roadmap

It demonstrates product thinking, engineering execution, and practical handling of real operational constraints.

---

## Review Order (For Companies)

For partnership, hiring, or technical due diligence, review in this order:

1. `README.md`
2. `SECURITY.md`
3. `supabase-security-hardening.sql`
4. `docs/data-model.md`
5. `docs/admin-workflows.md`
6. `docs/deployment.md`

---

## Contact/Attribution Block (Fill Before Sharing)

**Owner Name:** `Redmoon`  
**Project Name:** `Business Operations Platform`  
**Repository/Workspace Path:** `/home/redmoon/Desktop/Business-main`  
**Date Shared:** `2026-04-19`

---

## Final Statement

This is my web application, built to solve practical business operations problems with a clear path from MVP to production-grade security and governance.
