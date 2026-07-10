---
title: Financial Management — Full Stack
status: draft
primary_domain: financial
secondary_domains: [billing, auth, frontend, infrastructure]
created: 2026-07-09
applies_to: >
  evo-billing-service, evo-auth-service-community,
  evo-ai-frontend-community, docker-compose.yml,
  vps-docker-compose.yml, nginx
adr_ref: docs/adr/ADR-003-billing-service-architecture.md
file_relationship: INDEPENDENT
---

# Spec: Financial Management — Full Stack

## 1. Goal

Implement a complete, multi-tenant financial management system for Evolution CRM
Community covering two money flows:

1. **Platform → Tenant (SaaS)**: The platform charges each tenant a recurring
   subscription (monthly or annual) tied to a plan tier with defined usage limits.
2. **Tenant → Contacts (B2B2C)**: Each tenant creates and manages charges against
   their own end-customers (contacts), collecting PIX/Boleto/Cartão payments and
   issuing NF-e fiscal documents via Asaas.

The system is delivered in 4 sequential phases. Each phase has its own gate
evidence. The `/ship` command MUST NOT be invoked for a phase unless all ACs for
that phase are verified and passing.

---

## 2. Acceptance Criteria

### Phase 1 — Service Foundation + Schema + Plans/Subscriptions CRUD

> Gate: `bundle exec rspec spec/` GREEN + tenant isolation spec PASS

#### P1-AC-01 — Rails service scaffold
A new directory `evo-billing-service/` exists at the monorepo root containing a
Rails 7 API-only application. The app boots without error (`rails s` exits
cleanly or the health endpoint responds `200 OK`).

#### P1-AC-02 — Isolated PostgreSQL database
The service connects to its own PostgreSQL database (`evo_billing_{env}`) distinct
from the `evo_auth` database. No foreign key constraints cross databases.

#### P1-AC-03 — Schema: Plans table
A `plans` table exists with columns:
`id`, `name` (string, not null), `slug` (string, unique), `tier`
(enum: free/starter/pro/enterprise), `price_monthly_cents` (integer),
`price_annual_cents` (integer), `annual_discount_pct` (decimal),
`limit_instances` (integer), `limit_agents` (integer),
`limit_messages_per_month` (integer), `active` (boolean, default true),
`created_at`, `updated_at`.

#### P1-AC-04 — Schema: Subscriptions table
A `subscriptions` table exists with columns:
`id`, `account_id` (integer, not null, indexed), `plan_id` (fk → plans),
`billing_cycle` (enum: monthly/annual), `status`
(enum: trial/active/past_due/canceled, default: trial),
`trial_ends_at` (datetime), `current_period_start` (date),
`current_period_end` (date), `grace_period_ends_at` (datetime),
`canceled_at` (datetime), `created_at`, `updated_at`.

#### P1-AC-05 — Schema: Invoices + InvoiceItems + Payments tables
Three tables exist:
- `invoices`: `id`, `account_id` (indexed), `subscription_id` (fk), `status`
  (enum: draft/open/paid/void), `subtotal_cents`, `total_cents`, `currency`
  (default: BRL), `due_date` (date), `paid_at` (datetime), `created_at`,
  `updated_at`.
- `invoice_items`: `id`, `invoice_id` (fk), `description` (string),
  `quantity` (integer), `unit_price_cents` (integer), `total_cents` (integer).
- `payments`: `id`, `account_id` (indexed), `invoice_id` (fk, nullable),
  `asaas_payment_id` (string, unique, nullable), `method`
  (enum: pix/boleto/credit_card), `status`
  (enum: pending/confirmed/failed/refunded), `amount_cents` (integer),
  `paid_at` (datetime), `created_at`, `updated_at`.

#### P1-AC-06 — Multi-tenant scoping (isolation)
Every model (`Plan` is global; `Subscription`, `Invoice`, `InvoiceItem`,
`Payment`) that is tenant-scoped has `default_scope { where(account_id:
Current.account_id) }`. A request authenticated as Tenant A MUST NOT return
records belonging to Tenant B. Verified by an RSpec example:
```ruby
it 'does not return invoices from another tenant' do
  get api_v1_invoices_path, headers: headers_for(tenant_a)
  expect(json_ids).not_to include(invoice_from_tenant_b.id)
end
```

#### P1-AC-07 — JWT authentication
All `/api/v1/*` endpoints require a valid JWT Bearer token issued by
`evo-auth-service`. Requests without a token or with an invalid token return
`401 Unauthorized`. The public key used for validation is loaded from
`ENV["EVO_AUTH_JWT_PUBLIC_KEY"]`.

#### P1-AC-08 — Plans CRUD endpoints (superadmin only)
The following REST endpoints exist and respond correctly:
- `GET  /api/v1/plans` → 200, list of active plans (public, no auth required)
- `GET  /api/v1/plans/:id` → 200 or 404
- `POST /api/v1/plans` → 201 (superadmin only) or 403
- `PATCH /api/v1/plans/:id` → 200 (superadmin only) or 403
- `DELETE /api/v1/plans/:id` → 204 soft-delete: sets `active=false` (superadmin only)

#### P1-AC-09 — Subscriptions CRUD endpoints
- `GET  /api/v1/subscriptions/current` → 200, returns the active subscription for
  the authenticated tenant; 404 if none.
- `POST /api/v1/subscriptions` → 201, creates a subscription for the tenant
  (admin only); returns 409 if an active subscription already exists.
- `PATCH /api/v1/subscriptions/:id` → 200, allows changing plan or billing_cycle.
- `DELETE /api/v1/subscriptions/:id` → 200, sets status to `canceled`.

#### P1-AC-10 — Invoices read endpoints
- `GET /api/v1/invoices` → 200, paginated list scoped to the authenticated tenant.
- `GET /api/v1/invoices/:id` → 200 or 404.
- Superadmin: `GET /api/v1/admin/invoices` → 200, all invoices across tenants
  with `?account_id=` filter.

#### P1-AC-11 — Health endpoint
`GET /health` responds `200 OK` with JSON `{ status: "ok", service:
"evo-billing-service" }` without requiring auth.

#### P1-AC-12 — Docker Compose integration (local)
`docker-compose.yml` includes an `evo-billing` service entry with:
- Correct image reference or build context
- `DATABASE_URL` pointing to a dedicated `evo_billing_development` database
- Health check configured
- Traefik labels: `traefik.http.routers.billing.rule=PathPrefix('/billing/')`

#### P1-AC-13 — RSpec coverage gate
`bundle exec rspec spec/` returns exit code 0. Coverage includes:
- Model unit specs for `Plan`, `Subscription`, `Invoice`, `Payment`
- Request specs for all P1-AC-08/09/10 endpoints
- Tenant isolation spec (P1-AC-06 example passes)

---

### Phase 2 — Asaas Integration + Payments + Webhooks + Enforcement

> Gate: `bundle exec rspec spec/` GREEN + Playwright E2E billing flow PASS + VPS smoke PASS

#### P2-AC-01 — Schema: Customers + ContactCharges + AsaasWebhookEvents + NfeDocuments
Four additional tables exist:
- `customers`: `id`, `account_id` (indexed), `contact_id` (integer, reference to
  CRM contact), `asaas_customer_id` (string, unique), `name`, `cpf_cnpj`,
  `email`, `phone`, `created_at`, `updated_at`.
- `contact_charges`: `id`, `account_id` (indexed), `customer_id` (fk),
  `description`, `amount_cents`, `due_date`, `billing_method`
  (enum: pix/boleto/credit_card), `status`
  (enum: pending/confirmed/overdue/canceled), `asaas_charge_id` (string, unique),
  `payment_link` (string), `created_at`, `updated_at`.
- `asaas_webhook_events`: `id`, `event_id` (string, unique — idempotency key),
  `event_type` (string), `payload` (jsonb), `processed` (boolean, default false),
  `processed_at` (datetime), `created_at`.
- `nfe_documents`: `id`, `account_id` (indexed), `payment_id` (fk → payments),
  `asaas_nfe_id` (string), `nfe_number` (string), `pdf_url` (string),
  `xml_url` (string), `issued_at` (datetime), `created_at`, `updated_at`.

#### P2-AC-02 — Asaas customer sync
`POST /api/v1/customers` creates a Customer record AND syncs to Asaas API,
returning and storing `asaas_customer_id`. On failure from Asaas, the local
record is NOT persisted (transactional rollback). Returns `422` with error detail
if Asaas returns error.

#### P2-AC-03 — Contact charge creation
`POST /api/v1/contact_charges` creates a charge in Asaas for the given Customer
and stores the `asaas_charge_id` + `payment_link`. The tenant can specify
`billing_method` (PIX, Boleto, Cartão). Returns `201` with `payment_link` in
the response body so the tenant can share it with the contact.

#### P2-AC-04 — Webhook endpoint security
`POST /webhooks/asaas` validates the `asaas-signature` HMAC-SHA256 header
against `ENV["ASAAS_WEBHOOK_SECRET"]` before processing any event. Requests with
an invalid or missing signature return `401 Unauthorized` and are logged to
`AsaasWebhookEvent` with `processed: false` and a `signature_invalid` note.

#### P2-AC-05 — Webhook idempotency
If the same Asaas `event_id` is received twice (Asaas retries), the second
request responds `200 OK` without re-processing the event. The
`AsaasWebhookEvent` record shows `processed: true` from the first delivery.

#### P2-AC-06 — Webhook event handling
The following Asaas events are handled:
- `PAYMENT_CONFIRMED` → Payment status set to `confirmed`; linked Invoice set to
  `paid`; Subscription (if applicable) transitioned to `active`.
- `PAYMENT_OVERDUE` → Payment/Charge status set to `overdue`; Subscription (if
  applicable) transitioned to `past_due`; `grace_period_ends_at` set to
  `Time.current + 7.days`.
- `PAYMENT_REFUNDED` → Payment status set to `refunded`; Invoice status set to
  `void`.

#### P2-AC-07 — Enforcement job (dunning)
A Sidekiq job `DailySubscriptionEnforcementJob` runs daily (via Sidekiq-Cron at
03:00 UTC). It:
1. Finds all `Subscription` records with `status: past_due` AND
   `grace_period_ends_at < Time.current`.
2. For each, calls `POST /internal/accounts/:account_id/suspend` on evo-auth
   (authenticated with `ENV["INTERNAL_API_SECRET"]`).
3. Creates an `AuditLog` entry with `action: suspend`, `actor: system`,
   `reason: past_due_grace_expired`, `account_id`, `timestamp`.
4. On success, logs at INFO level. On failure (evo-auth unreachable), retries
   up to 3 times with exponential backoff; does NOT mark as failed silently.

#### P2-AC-08 — Auto-unsuspend on payment
When a `PAYMENT_CONFIRMED` webhook is received for a past_due Subscription:
1. Subscription transitions to `active`; `grace_period_ends_at` cleared.
2. `POST /internal/accounts/:account_id/unsuspend` called on evo-auth.
3. `AuditLog` entry created: `action: unsuspend`, `actor: system`,
   `reason: payment_confirmed`.

#### P2-AC-09 — evo-auth internal endpoints
`evo-auth-service-community` exposes (internal network only, not via Traefik):
- `POST /internal/accounts/:id/suspend` → sets `account.suspended = true`; returns 200.
- `POST /internal/accounts/:id/unsuspend` → sets `account.suspended = false`; returns 200.
Both endpoints require `Authorization: Bearer <INTERNAL_API_SECRET>` header.
Requests without valid secret return `403 Forbidden`.

#### P2-AC-10 — Suspended account enforcement at login
In `evo-auth`, when a suspended account's user attempts to log in or refresh
a token, the response is `403 Forbidden` with body `{ error: "account_suspended",
message: "Your subscription is overdue. Please update your payment." }`.

#### P2-AC-11 — NF-e request
`POST /api/v1/payments/:id/nfe` triggers NF-e emission via Asaas fiscal API.
On success, creates an `NfeDocument` record with `pdf_url` and `xml_url`.
Returns `201` with the NF-e document data. Only works for payments with
`status: confirmed`.

#### P2-AC-12 — Asaas mock in CI
All Asaas HTTP calls in specs use `WebMock` stubs (or VCR cassettes). No real
Asaas API calls are made during `bundle exec rspec`. The mock fixtures cover
all scenarios in P2-AC-02/03/04/06.

#### P2-AC-13 — Playwright E2E: payment flow
A Playwright test covers the full flow:
1. Superadmin creates a Plan via API.
2. Tenant subscribes to the Plan.
3. An invoice is generated.
4. A simulated Asaas `PAYMENT_CONFIRMED` webhook is sent to the billing service.
5. The invoice transitions to `paid` and the subscription to `active`.
6. Assert: the tenant's subscription status is `active` in the billing API.

#### P2-AC-14 — VPS smoke test
After deploy to VPS: `GET /billing/health` returns `200 OK`. A sample Plan is
readable via `GET /billing/api/v1/plans`. No 5xx errors in Traefik logs for 5
minutes post-deploy.

---

### Phase 3 — Frontend Dashboard + Reports + UI

> Gate: Playwright UI flows PASS + VPS smoke PASS

#### P3-AC-01 — Route namespace
The React app (`evo-ai-frontend-community`) has a `/financial` route namespace
accessible to authenticated users. Unauthenticated navigation to `/financial/*`
redirects to login.

#### P3-AC-02 — Superadmin: Plan management page
At `/financial/plans`, a superadmin can:
- View a table of all plans with name, tier, monthly price, annual price, status.
- Create a new plan via a form (validated client-side before submission).
- Edit a plan (inline edit or modal).
- Deactivate a plan (soft-delete; plan disappears from the list after refresh).

#### P3-AC-03 — Superadmin: All-tenant subscriptions page
At `/financial/subscriptions`, a superadmin sees a paginated table of all tenant
subscriptions with columns: account name, plan, status, billing cycle, next
renewal date. Filterable by status.

#### P3-AC-04 — Tenant admin: Own subscription page
At `/financial/subscription`, a tenant admin sees their current subscription:
plan name, tier, status badge (color-coded: green=active, yellow=trial,
red=past_due, gray=canceled), next billing date, billing cycle.
A "Upgrade Plan" button navigates to the plan selection page.

#### P3-AC-05 — Tenant admin: Invoice list
At `/financial/invoices`, a tenant admin sees their invoice history:
invoice number, due date, total, status, a "Download" link (PDF, if Asaas
returns a payment link or hosted page). Paginated.

#### P3-AC-06 — Tenant admin: Contact charges
At `/financial/charges`, a tenant admin can:
- View a list of all contact charges with customer name, amount, status, due date.
- Create a new charge (select customer, amount, method, due date).
- View payment link for each pending charge (copyable button).

#### P3-AC-07 — Superadmin: MRR Dashboard
At `/financial/dashboard`, a superadmin sees:
- **MRR card**: Monthly Recurring Revenue (sum of active monthly subscription prices
  + annual prices / 12), displayed in BRL.
- **Churn card**: Count of subscriptions canceled in the current calendar month.
- **Overdue card**: Count of subscriptions in `past_due` status.
- **Revenue chart**: Line chart of daily/monthly collected payments over the last
  12 months (data from the Payments API).

#### P3-AC-08 — Export CSV/Excel
On the invoices page and the payments page, an "Export" button downloads a
CSV file containing all records (not just the current page) matching the
active filters. The CSV includes all displayed column data.

#### P3-AC-09 — Playwright UI tests
Playwright tests cover:
- Superadmin creates a Plan and verifies it appears in the list.
- Tenant admin views their subscription status.
- Tenant admin creates a contact charge and copies the payment link.
- Superadmin views the MRR dashboard and verifies card values are non-zero.
- CSV export: the downloaded file is non-empty and has a header row.

---

### Phase 4 — NF-e Deep Integration + Fiscal Reports

> Gate: NF-e generated and downloadable in staging environment

#### P4-AC-01 — Automatic NF-e on payment confirmation
When a `PAYMENT_CONFIRMED` webhook is received for a `ContactCharge` or a
Platform Invoice, the system automatically requests NF-e emission from Asaas
without manual intervention. An `NfeDocument` record is created.

#### P4-AC-02 — NF-e download in frontend
On the invoice detail page and the contact charges page, a "Download NF-e"
button is displayed when `NfeDocument.pdf_url` is present. The button opens the
PDF in a new tab. If no NF-e is available, the button is hidden (not disabled,
not showing an error).

#### P4-AC-03 — NF-e failure handling
If Asaas fiscal API returns an error during NF-e emission, the payment/charge
is NOT rolled back. A `nfe_error` field on `NfeDocument` stores the error
message. A background retry job attempts re-emission up to 3 times (24h apart).
The admin can trigger manual retry via `POST /api/v1/payments/:id/nfe/retry`.

#### P4-AC-04 — Fiscal summary report
`GET /api/v1/admin/reports/fiscal` returns a JSON summary:
`{ total_nfe_issued, total_nfe_pending, total_nfe_failed, period: { from, to } }`.
Filterable by `from` and `to` query params (ISO date strings).

---

## 3. Non-Goals

The following are explicitly OUT OF SCOPE for this spec and must NOT be
implemented without a new spec:

- **NG-01**: Multi-currency support (only BRL in this spec; USD/EUR deferred).
- **NG-02**: Manual payment reconciliation UI (bank slip reconciliation outside
  Asaas is out of scope).
- **NG-03**: Proration for mid-cycle plan upgrades (subscription changes take
  effect at the next billing cycle).
- **NG-04**: Partner/affiliate commission tracking.
- **NG-05**: In-app payment collection (the system links to Asaas-hosted pages;
  it does NOT embed a credit card form within the CRM frontend).
- **NG-06**: Multiple concurrent active subscriptions per tenant (one active
  subscription per `account_id` at a time).
- **NG-07**: Pay-as-you-go / metered billing (usage-based pricing is out of scope;
  usage limits trigger enforcement, not variable charges).
- **NG-08**: External NF-e emitters (NFe.io, Focus NFe) — Asaas native only.
- **NG-09**: Stripe or any other payment gateway besides Asaas.
- **NG-10**: Email notifications (dunning emails, invoice delivery by email) —
  deferred to a future spec integrating with `evo-flow` campaign engine.

---

## 4. Constraints

- **C-01 — Tenant isolation**: Every database query on a tenant-scoped model MUST
  be filtered by `account_id`. Queries without a scoped `Current.account_id`
  context MUST raise an error (not silently return all records).
- **C-02 — Secrets**: `ASAAS_API_KEY`, `ASAAS_WEBHOOK_SECRET`, and
  `INTERNAL_API_SECRET` MUST NOT appear in source code, git history, or logs.
  They are injected via environment variables only.
- **C-03 — Financial precision**: All monetary values MUST be stored as integer
  cents (not float/decimal). Use `money-rails` for arithmetic and display.
- **C-04 — Internal endpoint network isolation**: `evo-auth` internal endpoints
  (`/internal/*`) MUST NOT be exposed through Traefik to the public internet.
  They are accessible only within the Docker internal network.
- **C-05 — Audit trail**: Every suspend/unsuspend action on an account MUST
  produce an immutable audit log entry. Audit logs MUST NOT be deletable via API.
- **C-06 — Idempotent webhooks**: Webhook processing MUST be idempotent. Re-
  delivering the same event ID must not cause duplicate database writes or
  double-charges.
- **C-07 — Grace period floor**: The grace period for past_due subscriptions is
  fixed at 7 days. It MUST NOT be shortened by configuration or code without
  updating this spec and ADR-003.
- **C-08 — Production tenants**: Body Harmony and Tiago_Araujo are in production.
  Any change to `evo-auth` (internal endpoints, suspension logic) requires a
  passing RSpec regression suite before deploy.

---

## 5. API / Data Contract

### Authentication
All `evo-billing-service` endpoints (except `GET /health` and `GET /api/v1/plans`)
require:
```
Authorization: Bearer <JWT issued by evo-auth>
```
JWT claims required: `sub` (user_id), `account_id`, `role` (superadmin | admin | agent).

### Internal S2S (evo-billing → evo-auth)
```
POST /internal/accounts/:id/suspend
POST /internal/accounts/:id/unsuspend
Authorization: Bearer <INTERNAL_API_SECRET>
Content-Type: application/json
```
Response: `{ success: true, account_id: <id>, status: \"suspended\"|\"active\" }`

### Asaas Webhook Ingress
```
POST /webhooks/asaas
asaas-signature: <HMAC-SHA256 hex digest>
Content-Type: application/json
```
Body follows Asaas webhook schema v3. See Asaas docs for payload structure.

### Key Response Envelopes
```json
// Success list
{ \"data\": [...], \"meta\": { \"page\": 1, \"per_page\": 25, \"total\": 100 } }

// Success single
{ \"data\": { ... } }

// Error
{ \"error\": \"<code>\", \"message\": \"<human readable>\", \"details\": {} }
```

---

## 6. State Metadata

- `status: draft` — awaiting user approval before freezing.
- On user approval: update frontmatter `status: draft → frozen`.
- Do NOT write to `current_state.md` at this stage (Write Isolation — Spec Index
  is updated only by `/ship`).

---

## 7. File Relationship

`INDEPENDENT` — This spec does not extend or replace any existing spec.

Related shipped specs (read-only reference):
- `docs/specs/tenant-isolation-auth.md` (status: shipped) — tenant scoping
  pattern this spec inherits via ADR-002.

---

## 8. Domain Decisions

- [DECISION] A dedicated `evo-billing-service` microservice is preferred over
  embedding billing in `evo-auth` or `evolution-go` because it provides blast
  radius isolation, independent scalability, and allows the financial domain to\n  evolve without risking production auth or messaging services. (Ref: ADR-003 D1)

- [DECISION] Rails/Ruby is chosen for `evo-billing-service` because `ActiveRecord`,\n  `money-rails`, and `pay` gems provide battle-tested financial domain primitives\n  that would require significant custom boilerplate in Go or NestJS. (Ref: ADR-003)

- [DECISION] Asaas is the sole payment gateway because it natively supports PIX,\n  Boleto, Cartão de Crédito, and NF-e emission in a single API, eliminating the\n  need for a separate fiscal service. (Ref: ADR-003 D6, D9)

- [CONSTRAINT] All monetary values MUST be stored as integer cents using\n  `money-rails`. Floating-point arithmetic for currency is permanently prohibited\n  in this domain.

- [CONSTRAINT] Every tenant-scoped model MUST carry `account_id` with a\n  `default_scope`. Bypassing the scope (`.unscoped`) requires an explicit\n  superadmin context guard and a comment explaining why.

- [TRADEOFF] The B2B2C billing flow (tenant charges contacts) shares the same\n  service as SaaS platform billing (platform charges tenants). This creates a\n  larger service responsibility but eliminates a third microservice and reduces\n  operational overhead. Accepted because both flows share the same domain\n  entities (Customer, Invoice, Payment) and gateway integration.

- [TRADEOFF] Cross-service operations (evo-billing suspend → evo-auth enforce)\n  are eventually consistent rather than transactionally atomic. A daily\n  reconciliation job is the compensating mechanism. Accepted because strict\n  distributed transactions (2PC/saga) would add excessive complexity for a\n  low-frequency operation (dunning runs once daily).

- [CONSTRAINT] The `ASAAS_API_KEY`, `ASAAS_WEBHOOK_SECRET`, and\n  `INTERNAL_API_SECRET` environment variables MUST be present at container boot.\n  The Rails initializer MUST raise at startup if any of these are absent in\n  non-test environments.

- [DECISION] NF-e is handled via Asaas native fiscal API in Phase 4. External\n  NF-e emitters (NFe.io, Focus NFe) are deferred to avoid a second paid SaaS\n  dependency before validating Asaas fiscal coverage.

- [CONSTRAINT] The `/internal/*` endpoints on evo-auth MUST NOT be routed\n  through Traefik. They are accessible only within the Docker bridge network,\n  verified by the absence of any `traefik.*` labels on those route definitions.
