# Spec: Multi-Tenant Scoping and Security Isolation

## Status
Draft

## 1. Goals
- Eliminate user/role data leakage between tenants in the `evo-auth` service.
- Implement automatic tenant database scoping for Go (`evo-ai-core-service-community`) and Python (`evo-ai-processor-community`) services.
- Prevent "Noisy Neighbor" resource starvation through Redis rate-limiting and Sidekiq concurrency limits.

## 2. Acceptance Criteria (AC)
- **AC-1 (Rails User Isolation)**: A request to `GET /api/v1/users` made by a user belonging to tenant `A` MUST only return users belonging to tenant `A`. Users of other tenants must not be visible.
- **AC-2 (Rails Agent Invites)**: Creating an agent through the `AgentBuilder` or `/users` API MUST automatically assign the inviter's `account_id` to the new user.
- **AC-3 (Go Service Scoping)**: Any query to tenant-scoped tables (e.g. `evo_core_agents`) in the Go service MUST automatically inject the current request's `account_id` derived from the validated JWT token.
- **AC-4 (Python Service Scoping)**: Any SQLAlchemy query to tenant-scoped tables in the Python service MUST automatically inject the request's `account_id`.
- **AC-5 (Noisy Neighbor Mitigation)**: Middleware must throttle requests from a single tenant/IP when threshold is exceeded, and Sidekiq must manage concurrency limits per `account_id`.

## 3. Test & Verification Plan
- **RSpec (evo-auth)**:
  - Create `spec/requests/api/v1/users_spec.rb` to assert that users belonging to other accounts are not visible in `GET /api/v1/users`.
  - Assert that `POST /api/v1/users` copies the inviter's `account_id`.
- **Integration Tests**:
  - Perform live validation by creating a secondary tenant and ensuring they cannot query the first tenant's agents, channels, or users.
