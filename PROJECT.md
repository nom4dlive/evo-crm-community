# Project: Multi-Tenant CRM

## Architecture
Multi-tenant architecture dividing the monorepo submodules into isolated logical partitions using tenant context:
- Central Identity Provider: `evo-auth-service-community`
- Core CRM Backend: `evo-ai-crm-community`
- WhatsApp Gateway API: `evolution-api`
- Python Dashboard: `evo-nexus`

```
  +-------------------------+
  |      Nginx Gateway      | (Propagates X-Tenant-ID / JWT)
  +------------+------------+
               |
               v
  +------------+------------+--------------------+
  |                         |                    |
  v                         v                    v
+--------------+          +------------+       +------------+
| Auth Service |          |    CRM     |       | Whatsapp   |
| (Rails)      |          | (Rails)    |       | API        |
| tenant_id    |          | tenant_id  |       | (NestJS)   |
+--------------+          +------------+       | tenantId   |
                                               +------------+
```

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | E2E Testing Suite | Create E2E test harness and tests across Tiers 1-4. Publish `TEST_READY.md`. | None | IN_PROGRESS (Conv ID: cdf88703-c3e8-4bc1-87f2-6842eddd0912) |
| 2 | Rails Schema Migration | Generate DB migrations adding `account_id` to CRM and Auth key tables. | None | IN_PROGRESS (Conv ID: 6fe7b732-73df-4805-99b4-d09c09e5b889) |
| 3 | Evolution Prisma Schema | Add `tenantId` to Prisma schema for `evolution-api` and run migrations. | None | IN_PROGRESS (Conv ID: cc88f695-275b-44b4-a07d-56c5efca61f5) |
| 4 | Nexus SQLAlchemy Models | Implement tenant scoping in Flask SQLAlchemy models (`User`, `AuditLog`). | None | IN_PROGRESS (Conv ID: 2632f900-729b-49d7-a711-1a28601466ef) |
| 5 | Request-Scoped Resolution | Adapt `EvoAuthConcern` to extract tenant, set `Current.account`, and scope ActiveRecords. | M2 | PLANNED |
| 6 | WhatsApp & Queue Isolation | Scope Baileys connection and isolate RabbitMQ/Sidekiq queues per tenant. | M3, M5 | PLANNED |
| 7 | Full Integration Gate | Run E2E tests, resolve failures, and execute Tier 5 adversarial checks. | M1, M2, M3, M4, M5, M6 | PLANNED |

## Interface Contracts
### Gateway ↔ Services
- The ingress proxy (Nginx) MUST forward:
  - `X-Tenant-ID` header (resolved from host subdomain or explicitly sent).
  - `Authorization: Bearer <JWT>` containing a `tenant_id` claim in payload.

### CRM ↔ Auth
- Token validation validation payload from Auth service MUST contain:
  - `user`: { `id`, `email`, `account_id` }
  - `account`: { `id`, `name` }

### Code Layout
- Migrations:
  - Auth Service: `evo-auth-service-community/db/migrate/`
  - CRM Service: `evo-ai-crm-community/db/migrate/`
  - NestJS API: `evolution-api/prisma/migrations/`
- Models:
  - Nexus: `evo-nexus/dashboard/backend/models.py`
