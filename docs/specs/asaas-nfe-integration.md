---
title: Asaas NF-e Integration & Fiscal Reports
status: shipped
primary_domain: financial
secondary_domains: [billing, auth, frontend]
created: 2026-07-10
applies_to: evo-billing-service, evo-ai-frontend-community
adr_ref: docs/adr/ADR-003-billing-service-architecture.md
file_relationship: EXTENDS docs/specs/financial-management.md
---

# Spec: Asaas NF-e Integration & Fiscal Reports

## 1. Goal
Implement automatic municipal service invoice (NFS-e) emission when a payment (platform subscription invoice) or contact charge (tenant to client charge) is confirmed, along with frontend download links, failure retries, and a consolidated fiscal report endpoint.

---

## 2. Acceptance Criteria (AC)

### P4-AC-01 — Automatic NF-e on Payment Confirmation
- When a payment is confirmed via `Webhooks::AsaasController`:
  - Trigger a Sidekiq background job (`NfeEmissionJob`) to handle invoice emission asynchronously.
  - The job calls Asaas `POST /v3/invoices` passing `{"payment": "pay_..."}` or the relevant identifier.
  - On success, create or update `NfeDocument` with Asaas `id`, `number`, `pdf_url`, `xml_url`, and clear `nfe_error`.

### P4-AC-02 — NF-e Download in Frontend
- Display a "Baixar NF-e" button on:
  - The tenant invoice listing and details (`InvoicesPage.tsx`).
  - The contact charges listing (`ChargesPage.tsx`).
- The button is visible ONLY when `pdf_url` in the `nfe_document` payload is present. Clicking it opens the PDF in a new tab.

### P4-AC-03 — NF-e Failure Handling & Retries
- If the Asaas API returns a temporary or persistent error during emission:
  - Do NOT roll back the payment/charge confirmation status.
  - Save the error message in the `nfe_error` field of `NfeDocument`.
  - For temporary or external failures, the job retry logic must execute up to 3 times, spaced 24 hours apart.
  - Expose a manual retry endpoint `POST /api/v1/payments/:id/nfe/retry` (and `POST /api/v1/contact_charges/:id/nfe/retry`) for tenant admins.

### P4-AC-04 — Fiscal Summary Report
- Expose a superadmin endpoint `GET /api/v1/admin/reports/fiscal`.
- Returns:
  ```json
  {
    "total_nfe_issued": 10,
    "total_nfe_pending": 2,
    "total_nfe_failed": 1,
    "period": { "from": "2026-07-01", "to": "2026-07-10" }
  }
  ```
- Filterable by `from` and `to` ISO date parameters.

---

## 3. API Contract

### Retry NF-e Emission
```
POST /api/v1/payments/:id/nfe/retry
POST /api/v1/contact_charges/:id/nfe/retry
Authorization: Bearer <JWT>
```
Response:
- `200 OK` on successfully queueing retry.

### Fiscal Report
```
GET /api/v1/admin/reports/fiscal?from=2026-07-01&to=2026-07-10
Authorization: Bearer <Superadmin JWT>
```
Response:
- `200 OK` with JSON envelope matching P4-AC-04.
