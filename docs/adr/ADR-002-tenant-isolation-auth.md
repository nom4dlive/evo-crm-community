---
date: 2026-07-08
lifecycle:
  owner: "unassigned"
  review_cadence: "on-event"
  review_trigger: "Multi-tenant query scoping policies or auth token claims changed"
  supersedes: "none"
  superseded_by: "none"
---
# ADR-002: Multi-Tenant Scoping and Security Isolation


## Status
Proposed

## Context
Evolution CRM is a microservice-based multi-tenant application. It shares a single database (`evocrm`) across services. 
While `evo-crm` (Ruby on Rails) implements strict tenant isolation using the `AccountScoped` concern to inject `account_id` filters in all queries, the `evo-auth` service (also Ruby on Rails) leaks data because it lacks database-level scoping on crucial user tables (such as `User` and `UserRole`). This allows a tenant administrator to view, update, or delete users belonging to other tenants.
Furthermore, the Go service (`evo-ai-core-service-community`) and Python service (`evo-ai-processor-community`) lack middleware-driven context propagation of `account_id` and query filtering in their community builds.

## Decision
We will establish a unified multi-tenant scoping and isolation architecture across the entire stack:
1. **Rails (evo-auth)**:
   - Port the `AccountScoped` concern to `evo-auth` to automatically inject `where(account_id: Current.account_id)` via `default_scope`.
   - Apply this concern to `User`, `UserRole`, `AccessToken`, `DataPrivacyConsent`, and `SetupSurveyResponse`.
   - Force newly invited users through `AgentBuilder` to inherit `account_id` from the inviter.
   - Limit `UsersController#index` to return users matching `current_user.account_id`.
   - Maintain globally unique emails (enforced by the DB index) to allow centralized login from `https://crm.bodyharmony.tech/login`.
2. **Go (evo-ai-core-service-community)**:
   - Create a Go middleware that extracts the `account_id` claim from JWT bearer / access tokens.
   - Propagate this context using `runtimecontext.WithID`.
   - Register GORM callbacks to automatically inject `Where("account_id = ?", accountID)` when querying tenant-scoped tables.
3. **Python (evo-ai-processor-community)**:
   - Create a FastAPI middleware to extract `account_id` from validated token data.
   - Use `contextvars` to store `account_id` per-request.
   - Intercept SQLAlchemy queries via `before_compile` to automatically append `where(Model.account_id == current_account_id)`.
4. **Queue/Redis Isolation**:
   - Limit Sidekiq concurrency per tenant to prevent the "Noisy Neighbor" problem without fragmenting Redis with dynamic queues.

## Alternatives Considered
- **acts_as_tenant Gem**: Rejected. Our native `AccountScoped` concern is lightweight, dependency-free, and already proven in `evo-crm`.
- **Dynamic Queue Prefixing**: Rejected for this phase. Dynamic Redis queue prefixing introduces management and monitoring complexity. Concurrency limiting by `account_id` is sufficient.

## Consequences
- **Positive**: Strict data isolation across tenants, preventing security breaches and token leakage.
- **Negative**: Development overhead in keeping non-Rails models synchronized with tenant scope configurations.
