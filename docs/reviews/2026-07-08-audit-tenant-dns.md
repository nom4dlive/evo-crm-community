# Audit Report — Tenant Subdomain Reservation & Resolution (2026-07-08)

This audit analyzes the root cause of the "Espaço Indisponível" error encountered when accessing the main CRM portal `https://crm.bodyharmony.tech/` and specifies the corrective action taken.

## 1. Finding: Subdomain "crm" Intercepted as Tenant Subdomain
- **Observation:** Accessing `https://crm.bodyharmony.tech/` returned the "Espaço Indisponível" error page, and clicking the "Voltar ao Inicio" link redirected to the dead/unconfigured domain `n4crm.ai`.
- **Root Cause:** 
  1. The newly compiled frontend includes a tenant-handshake mechanism where the sub-domain of the request hostname is dynamically resolved to find the corresponding tenant:
     - `crm.bodyharmony.tech` yields the subdomain `"crm"`.
  2. The resolved subdomain is validated against a blacklist of system domains (`SYSTEM_DOMAINS` in `src/utils/tenantUtils.ts`):
     - Reserved domains list: `['localhost', '127.0.0.1', 'app']`.
  3. Because `"crm"` was not present in `SYSTEM_DOMAINS`, the application treated `"crm"` as a valid tenant subdomain and performed a tenant handshake:
     - `GET /api/v1/tenants/handshake?subdomain=crm`
  4. The database has no tenant record matching subdomain `"crm"`, causing the handshake to return a `404 Not Found` or a network timeout.
  5. The frontend caught the error, set `tenantError = 'TENANT_NOT_FOUND'` or `'HANDSHAKE_FAILED'`, and rendered the "Espaço Indisponível" fallback screen.
  6. The `BASE_DOMAIN` defaults to `n4crm.ai` when the environment variable is not defined, leading to the DNS-failing link redirection.

## 2. Action Taken
- **Patcher Script:** Created and executed a python script to modify the active `SYSTEM_DOMAINS` variable inside the VPS file `/var/www/n4-crm/client-a/evo-ai-frontend-community/src/utils/tenantUtils.ts`.
- **Modifications:** Added `'crm'` to the reserved system domains:
  ```typescript
  const SYSTEM_DOMAINS = [
    'localhost',
    '127.0.0.1',
    'app', // Subdomínio de admin/superadmin genérico
    'crm', // Subdomínio do CRM principal
  ];
  ```
- **Rebuilt & Redeployed:** Ran `npx pnpm@9 build` inside the frontend directory on the VPS and copied the newly compiled static assets (`dist/*`) to the public directory `/var/www/crm/` served by Nginx.
- **Verification:** Accessing `https://crm.bodyharmony.tech/` now skips the tenant handshake logic, avoids the error state, and successfully loads the standard CRM login screen.

---

## 3. Routing Actions

```yaml
routing_actions:
  - finding: "System subdomain 'crm' missing from SYSTEM_DOMAINS reservations list in tenantUtils.ts"
    target_doc: "docs/specs/tenant-isolation-auth.md"
    status: pending
    owner: "unassigned"
```
