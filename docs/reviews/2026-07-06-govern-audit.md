# Governance Audit Report

**Baseline:** validate warn · 0 known findings excluded
**Findings:** 1 verified (1 do-now · 0 backlog · 0 closed) · 0 false alarms dropped

## Verified Findings

### 1. CORS Configuration Drift [do-now]
**Trigger:** CORS policy block on `auth-api.bodyharmony.tech`.
**Observation:** The frontend at `crm.bodyharmony.tech` was failing to authenticate because `evo-auth` was missing the correct `CORS_ORIGINS` environment variable in `docker-compose.yml`. As verified via the codebase graph (`config/initializers/cors.rb`), the API reads from `ENV['CORS_ORIGINS']`. Without it, it defaults to localhost origins, causing the preflight checks to reject production domains.
**Fix Applied:** `docker-compose.yml` was patched on the VPS to include `CORS_ORIGINS: "https://crm.bodyharmony.tech"` and the `evo-auth` container was recreated.

```yaml
routing_actions:
  - finding: "Missing CORS_ORIGINS for production frontend in docker-compose.yml"
    target_doc: "docs/architecture/evo-auth.md"
    status: pending
    owner: "unassigned"
```
