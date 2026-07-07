---
title: Environment Stabilization and Error Resolution
status: draft
---

# Specification — Environment Stabilization

This specification defines the acceptance criteria (AC) for stabilizing the production VPS environment at `api.bodyharmony.tech` and correcting the remaining gaps identified in the July 7th audit.

## Acceptance Criteria

### AC-1: Deploy NestJS `evo-flow` Service
- **Requirement**: The `evo-flow-community` (NestJS) application must be deployed on the production VPS.
- **Verification**: The service must run inside Docker and respond to liveness checks on its internal port.
- **Routing**: The gateway (`evocrm_gateway`) must route all requests matching `location ~ ^/api/v1/journeys` to the `evo-flow` container instead of the default `evo-crm` upstream.

### AC-2: Resolve Traefik Port Conflicts
- **Requirement**: The `traefik` container must run stably without hitting restart loops due to port conflicts with host Nginx.
- **Verification**: `docker ps` must show the Traefik container as `Up` (healthy) without continuous restarts.

### AC-3: Automation of Database Seeding
- **Requirement**: The database migration/deployment scripts or container entrypoints must ensure the database is seeded (`db:seed` for RBAC and RuntimeConfig) to prevent missing account/role records.
- **Verification**: `/api/v1/account` must return a successful `200 OK` response on fresh deployments.

### AC-4: EOL Line Ending Enforcement
- **Requirement**: All scripts inside `bin/` directories across submodules must use LF line endings.
- **Verification**: Checkouts on Windows must automatically convert these files to LF to prevent shebang failures in Linux Docker containers.

### AC-5: EvoFlow API Client Environment Configuration
- **Requirement**: The Rails CRM service must configure `AUTH_APIKEY_INTEGRATION_LOCAL`, `EVO_FLOW_ALLOW_INSECURE`, and `EVO_FLOW_API_URL` to authenticate and communicate with the NestJS `evo-flow` container.
- **Verification**: `GET /api/v1/segments` must respond with a successful HTTP response (401 or 200 depending on credentials) instead of yielding a `500 Internal Server Error`.
