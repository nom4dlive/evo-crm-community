# Governance Audit Report — VPS Port Conflict & Nginx Routing (2026-07-08)

**Baseline:** validate PASS · 0 known findings excluded
**Findings:** 3 verified (2 do-now · 0 backlog · 1 closed) · 0 false alarms dropped

---

## 1. Already-Known List
Open findings from the prior audit on 2026-07-08 (`docs/reviews/2026-07-08-govern-audit.md`) are active.

---

## 2. Verified Findings

### Finding 1: Traefik Port Binding Conflict [do-now]
- **Observation:** Traefik was configured in host network mode binding to port 80, conflicting with Nginx on the host VPS.
- **Verification:** Inspected `/docker/traefik/docker-compose.yml` and verified the `network_mode: host` setting.
- **Disposition:** do-now (Successfully patched Traefik to use port 8080 and 8443, enabling it to run cleanly alongside Nginx).

### Finding 2: Static Frontend served outside Docker [closed-with-reason]
- **Observation:** Even after deleting the `evolution-crm-mvp` docker project, the new CRM login page was still served.
- **Verification:** Inspected `/etc/nginx/sites-enabled/crm` and confirmed that Nginx runs directly on the host VPS and serves `/var/www/crm` statically, independent of the Docker containers state.
- **Disposition:** closed-with-reason (Working as intended. Static assets are served directly by the host Nginx for performance; only the backend APIs require the Docker containers to be running).

### Finding 3: Synchronization of Local Monorepo [do-now]
- **Observation:** VPS files had untracked and modified changes relating to tenant resolution and auth logic.
- **Verification:** Ran `git status` on the VPS and verified the file diffs.
- **Disposition:** do-now (Successfully synchronized the modified files locally via SCP to maintain repository alignment).

---

## 3. Routing Actions

```yaml
routing_actions:
  - finding: "Traefik network port conflict resolved by migration to ports 8080/8443"
    target_doc: "docs/specs/tenant-isolation-auth.md"
    status: pending
    owner: "unassigned"
```
