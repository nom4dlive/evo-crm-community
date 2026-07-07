# Original User Request

## Initial Request — 2026-07-06T17:25:49-03:00

Make the necessary adjustments so that the system has multi-tenant capability, elevating the quality of this CRM to be functional and perfect for companies willing to pay for high-level, safe WhatsApp automation services in production.

Working directory: F:\Evolution-CRM\evo-crm-community
Integrity mode: development

## System Architecture Context (Full Stack 360)

The monorepo contains 10 submodules:
1. **evo-auth-service-community** (Ruby on Rails): Central identity provider. Databases: `evo_community` (development/production).
2. **evo-ai-crm-community** (Ruby on Rails): Core CRM backend. Connects to `evo_community` (PostgreSQL). Authenticates users via `EvoAuthConcern` (verifying tokens against the auth service and setting `Current.user`).
3. **evolution-api** (NestJS): WhatsApp Gateway API. Uses Prisma (`prisma/postgresql-schema.prisma`) for managing `Instance`, `Chat`, `Message`, `Webhook`, `Typebot` models.
4. **evo-nexus** (Python/FastAPI/SQLAlchemy): Dashboard backend managing `User` and `AuditLog` in `dashboard/backend/models.py`.
5. **evo-flow-community** (NestJS) & **evo-bot-runtime** (Go): Bot execution, scheduling, and message queuing.

Currently, the system is designed for a single runtime account (e.g. no `tenant_id` or `account_id` in database schemas).

## Requirements

### R1. Multi-Tenant Database Schema Partitioning
Introduce an `Account` or `Tenant` model to represent corporate tenants. Partition the database schemas:
- **Rails services (Auth & CRM)**: Add `account_id` or `tenant_id` to key tables (`users`, `inboxes`, `contacts`, `conversations`, `messages`, `pipelines`, `products`, `integrations`, `webhooks`). Generate Rails database migrations in `db/migrate/` for both submodules.
- **evolution-api**: Add `tenantId` field to the `Instance` model in `prisma/postgresql-schema.prisma` (and corresponding Prisma migrations).
- **evo-nexus**: Implement scoping by tenant in SQLAlchemy `User` and `AuditLog` models in `models.py`.

### R2. Request-Scoped Tenant Resolution (Gateway & Auth)
- Adapt `EvoAuthConcern` in the CRM backend to extract the tenant context from the incoming request (JWT token claims, `X-Tenant-ID` header, or subdomain).
- Ensure that once resolved, `Current.tenant` (or `Current.account`) is set for the request scope, and all ActiveRecord queries automatically apply default scopes to filter by `tenant_id`.
- The gateway/proxy (`nginx` reverse proxy) must propagate the tenant headers to downstream services.

### R3. Safe WhatsApp Instance & Automation Isolation
- In `evolution-api`, scope WhatsApp Baileys connections (`whatsapp.baileys.service.ts`) and Meta Business APIs so that instances belong strictly to their parent tenant.
- Jobs processed by Sidekiq (`sidekiq.yml` in CRM/Auth) or RabbitMQ queues in `evolution-api` must be strictly isolated (e.g., separate queues or tenant-prefixed routing keys) to prevent a high-volume broadcast from one tenant impacting the safety or rate-limits of another tenant's WhatsApp numbers.

### R4. Automated Boundary & Security Testing
- Add integration tests that create two separate tenants (Tenant A and Tenant B).
- Programmatically verify that a user authenticated under Tenant A receives `403 Forbidden` or `404 Not Found` when trying to access or send messages through a WhatsApp `Instance` or `Inbox` belonging to Tenant B.
- Ensure all existing unit and E2E test suites in Rails (`spec/`), pytest (`tests/`), and NestJS (`test/`) continue to pass.

## Verification Resources (To Be Consulted)
- Database configs: `evo-auth-service-community/config/database.yml`, `evo-ai-crm-community/config/database.yml`
- Rails auth concern: `evo-ai-crm-community/app/controllers/concerns/evo_auth_concern.rb`
- Prisma schema: `evolution-api/prisma/postgresql-schema.prisma` (and the `Instance` model)
- Nexus SQLAlchemy models: `evo-nexus/dashboard/backend/models.py`

## Acceptance Criteria

### Data & Schema Isolation
- [ ] PostgreSQL migration scripts exist for CRM and Auth submodules to support multi-tenant relationships.
- [ ] Prisma migration scripts exist for `evolution-api` to add `tenantId` column to `Instance`.
- [ ] Attempting to access Tenant B's data via Tenant A's session results in a `403 Forbidden` or `404 Not Found`.

### Authentication & API Routing
- [ ] API requests to CRM, Auth, and Evolution APIs validate tenant scope on every request.
- [ ] A tenant creation endpoint or console command exists to register and bootstrap new tenants.

### WhatsApp Queue & Instance Safety
- [ ] Sidekiq/RabbitMQ message queues isolate background trigger execution per tenant context.
- [ ] All new multi-tenant boundary tests pass successfully.
