---
date: 2026-07-09
status: accepted
applies_to: ["evo-billing-service/**", "evo-auth-service-community/**", "evo-ai-frontend-community/**", "docker-compose.yml", "vps-docker-compose.yml", "nginx"]
lifecycle:
  owner: "unassigned"
  review_cadence: "on-event"
  review_trigger: "Billing model changes, new payment gateway added, or tenant enforcement policy changed"
  supersedes: "none"
  superseded_by: "none"
---

# ADR-003: Financial Management — evo-billing-service Architecture

## Status

Accepted

## Context

Evolution CRM Community is a multi-tenant SaaS platform with tenants in production
(Body Harmony, Tiago_Araujo). The platform currently has no financial management
capability — tenant onboarding is manual, there is no subscription lifecycle, no
automated billing, and no way for tenants to charge their own contacts/customers.

The product requires a **full-stack financial management module** covering two
distinct money flows:

1. **Platform → Tenant (SaaS billing)**: The platform owner charges each tenant
   a recurring subscription fee based on a plan tier (Free, Starter, Pro,
   Enterprise), with usage limits per plan (WhatsApp instances, AI agents,
   messages/month).

2. **Tenant → Contacts (B2B2C billing)**: Each tenant uses the CRM to create
   and manage charges to their own end-customers (contacts), collect PIX/Boleto/
   Cartão payments, and issue NF-e invoices.

The existing stack comprises:
- **Go** (`evolution-go`): WhatsApp core, message routing, instance management
- **Rails** (`evo-auth-service-community`): Auth, accounts, roles, users
- **Python** (`evo-ai-processor-community`): AI flows and processors
- **NestJS** (`evo-flow-community`): Journey and campaign orchestration
- **React/Vite** (`evo-ai-frontend-community`): Web UI

The gateway market research identified **Asaas** as the optimal Brazilian payment
gateway: it supports PIX, Boleto Bancário, Cartão de Crédito, and has native NF-e
emission, eliminating the need for a separate fiscal service integration in the
initial delivery.

## Decision

### D1 — New Dedicated Microservice: `evo-billing-service`

We will create a **new, standalone microservice** (`evo-billing-service`) rather
than embedding billing logic into an existing service.

**Stack**: Ruby on Rails (API-only mode) with:
- PostgreSQL (dedicated isolated database — no shared schema with other services)
- Sidekiq + Redis for background jobs (subscription enforcement, invoice generation)
- `money-rails` gem for precise decimal currency handling
- HTTP client for Asaas API integration (v3)
- JWT validation via shared public key from `evo-auth`

**Rationale**: Rails was chosen over the other stack members because:
- `ActiveRecord` provides mature support for financial domain modeling (state
  machines, callbacks, validations)
- The `pay` and `money-rails` gems are battle-tested billing primitives
- `evo-auth` is already Rails — sharing JWT validation patterns and conventions
  costs zero additional infrastructure expertise
- Go would require manual financial domain boilerplate; NestJS would add a JS
  runtime without meaningful gains; Python has weak financial gem ecosystem

### D2 — Domain Model

The following entities will be implemented in `evo-billing-service`:\n\n| Entity | Description |\n|---|---|\n| `Plan` | Platform-defined tiers (Free, Starter, Pro, Enterprise) with usage limits |\n| `Subscription` | Tenant ↔ Plan binding; states: `trial`, `active`, `past_due`, `canceled` |\n| `Invoice` | Billing document generated per cycle or manually; states: `draft`, `open`, `paid`, `void` |\n| `InvoiceItem` | Line item within an Invoice (plan fee, usage overage, one-time charge) |\n| `Payment` | Records each gateway transaction (PIX, Boleto, Cartão); linked to Invoice |\n| `Customer` | A contact of the tenant registered in Asaas as a billing customer |\n| `ContactCharge` | A charge the tenant creates against one of their Customers |\n| `AsaasWebhookEvent` | Raw incoming event from Asaas gateway (idempotency key, processed flag) |\n| `NfeDocument` | Fiscal note linked to a confirmed Payment |\n\nAll entities are scoped by `account_id` (tenant identifier), following the same
isolation pattern established in ADR-002. A `default_scope` on every model
enforces `where(account_id: Current.account_id)`.\n\n### D3 — Billing Cycles\n\nSubscriptions support **monthly** and **annual** billing cycles. Annual plans
carry a configurable discount percentage stored on the `Plan` record. No
quarterly or semi-annual cycles in this phase.\n\n### D4 — RBAC Model\n\n| Actor | Permissions |\n|---|---|\n| Superadmin (platform) | Full CRUD on Plans; read all Subscriptions; manually adjust any Invoice |\n| Tenant Admin | Read own Subscription; manage Customers and ContactCharges; view Invoices |\n| Tenant Agent | Read-only on Invoices; no access to financial configuration |\n\nAuthorization is enforced via policy objects (Pundit) in `evo-billing-service`,\nwith the actor role derived from the JWT claim validated against `evo-auth`.\n\n### D5 — Tenant Enforcement (Dunning)\n\nWhen a tenant's subscription transitions to `past_due`:\n\n1. A 7-day **grace period** is granted — the tenant retains full CRM access.\n2. After 7 days without payment, a `DailySubscriptionEnforcementJob` (Sidekiq,\n   scheduled via Sidekiq-Cron) calls `evo-auth` internal API:\n   `POST /internal/accounts/:account_id/suspend`\n3. `evo-auth` sets `account.suspended = true`, which causes all subsequent JWT\n   validations for that tenant to return `403 Suspended`.\n4. When payment is confirmed (via Asaas webhook), the subscription transitions\n   to `active` and `evo-auth` is called to unsuspend:\n   `POST /internal/accounts/:account_id/unsuspend`\n\nAn **audit log** records every suspend/unsuspend action with timestamp, actor,\nand reason to enable manual recovery in case of enforcement errors.\n\n### D6 — Asaas Integration\n\n- **Webhook validation**: Every `POST /webhooks/asaas` request MUST verify the\n  Asaas HMAC-SHA256 signature header (`asaas-signature`). Requests without a\n  valid signature are rejected with `401 Unauthorized` and never processed.\n- **Idempotency**: `AsaasWebhookEvent` stores the event ID; duplicate events\n  (Asaas retries) are silently acknowledged without re-processing.\n- **Environments**: `ASAAS_API_KEY` and `ASAAS_ENV` (`sandbox`|`production`) are\n  injected via environment variables only — never hardcoded or logged.\n  `config.filter_parameters` covers all Asaas key patterns.\n\n### D7 — Routing and Exposure\n\n`evo-billing-service` is routed via the existing Traefik gateway using a path\nprefix:\n- **Public/tenant-facing**: `https://{tenant-domain}/billing/` → billing service\n- **Superadmin**: `https://crm.bodyharmony.tech/billing/` (or platform domain)\n- **Internal only** (no public route): `/internal/` endpoints for service-to-service\n  communication between `evo-billing` and `evo-auth`\n\nInternal S2S calls are authenticated via a shared `INTERNAL_API_SECRET` env var\n(Bearer token), never via tenant JWT.\n\n### D8 — Frontend Integration\n\nFinancial UI lives as a **dedicated section inside `evo-ai-frontend-community`**:\n- New route namespace: `/financial/*`\n- Superadmin view: Plan management, all-tenant subscription list, MRR dashboard\n- Tenant Admin view: Own subscription, invoice history, contact charges\n- Dashboard widgets: MRR, churn rate, overdue count, revenue timeline chart\n- Data export: CSV/Excel for invoices and payments\n\n### D9 — NF-e Strategy\n\nNF-e emission will use **Asaas native fiscal integration** (they support NF-e for\nservices). A fallback to NFe.io or Focus NFe is deferred to a future ADR if Asaas\nfiscal coverage proves insufficient.\n\n## Alternatives Considered\n\n### Alt-1 — Embed billing in `evo-auth-service-community`\n**Rejected.** Auth is already responsible for identity and access control.\nAdding financial domain logic violates SRP, creates a God service, and makes\nindependent scaling and deployment of billing impossible. evo-auth is in\nproduction — adding new financial models increases regression risk to existing auth flows.\n\n### Alt-2 — Embed billing in `evolution-go` (Go core)\n**Rejected.** Go lacks mature financial domain tooling (no equivalent of\n`money-rails`, `pay`, or Pundit). The billing domain is CRUD-heavy and\nstate-machine driven — Go's strengths (concurrency, throughput) do not apply here.\nTight coupling to the WhatsApp core would make billing failures affect messaging.\n\n### Alt-3 — NestJS microservice\n**Rejected.** NestJS would be consistent with `evo-flow-community` but introduces\na third JS runtime with no meaningful advantage over Rails for this domain.\nTypeScript ORM ecosystems (Prisma, TypeORM) are less battle-tested for financial\nmodeling than ActiveRecord. The team would need to learn a new billing library\necosystem.\n\n### Alt-4 — Shared database schema with `evo-auth`\n**Rejected.** Sharing the PostgreSQL instance (even with a schema prefix) creates\nschema coupling — a migration in billing could lock tables used by auth, causing\nproduction auth outages. A dedicated database provides blast radius containment\nand independent backup/restore.\n\n### Alt-5 — Single Asaas integration at platform level only\n**Rejected.** The product requirement is dual-flow: the platform must charge\ntenants AND tenants must charge their own contacts. A platform-only Asaas\nintegration would require a second integration when the B2B2C flow is added later.\nThe unified `evo-billing-service` handles both flows under one service contract.\n\n## Consequences\n\n### Positive\n\n- **Blast radius isolation**: A billing bug or deployment failure does not affect\n  auth, messaging, or AI flows.\n- **Independent scaling**: Billing can be scaled horizontally without touching other\n  services.\n- **Dual-flow support**: The same service handles both SaaS billing (platform→tenant)\n  and B2B2C billing (tenant→contacts) with shared domain models.\n- **NF-e included**: Asaas natively handles fiscal emission — no additional service\n  or license needed initially.\n- **Tenant safety**: Grace period + audit log prevents accidental lockouts.\n\n### Negative\n\n- **New service to operate**: Adds one more container to the Traefik/Podman stack,\n  one more PostgreSQL database, one more Redis queue, and one more Sidekiq process.\n  Operational overhead increases.\n- **S2S auth surface**: The `evo-auth` internal suspend/unsuspend endpoints are a new\n  attack surface — they MUST be network-isolated (internal Docker network only) and\n  protected by `INTERNAL_API_SECRET`.\n- **Data consistency without transactions**: Cross-service operations (e.g.,\n  subscription cancellation in billing + account suspension in auth) are eventually\n  consistent — a crash mid-sequence can leave state inconsistent. Compensating\n  actions must be idempotent and re-triggerable by the daily enforcement job.\n\n## Implementation Phases\n\n| Phase | Scope | Gate |\n|---|---|---|\n| 1 | Service scaffold, schema, CRUD endpoints, multi-tenant scoping, JWT auth | RSpec unit + request specs + tenant isolation spec PASS |\n| 2 | Asaas integration, webhooks, ContactCharges, Sidekiq enforcement, NF-e | E2E Playwright + mock Asaas + smoke VPS PASS |\n| 3 | Frontend: dashboard, invoices, payments, charts, CSV export | Playwright UI flows + smoke VPS PASS |\n| 4 | NF-e deep integration, fiscal reports | NF-e generated and downloadable in staging |\n\n## References\n\n- ADR-001: `docs/adr/ADR-001-tenant-routing.md` — Traefik routing conventions this service follows\n- ADR-002: `docs/adr/ADR-002-tenant-isolation-auth.md` — tenant scoping pattern (`account_id` default_scope)\n- Spec (TBD): `docs/specs/financial-management.md`\n- Implementation plan: `.agentcortex/context/work/main.md`\n
