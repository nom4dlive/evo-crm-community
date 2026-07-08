# Audit Report — Hostinger DNS & Old CRM Routing (2026-07-08)

This audit maps the Hostinger domain configurations, active DNS records for `bodyharmony.tech`, and analyzes why the old CRM is still accessible at `https://bodyharmony.tech/`.

## 1. Hostinger Domains & Hosting Inventory
Using Hostinger MCP tools, we mapped the active assets on the account:

### Registered Domains:
- `bodyharmony.tech` (Domain ID: `31699215`) - Active
- `bodyharmony.com.br` (Domain ID: `15036359`) - Active
- `drulisseslopes.com` / `drulisseslopes.com.br` - Active
- `impacto3s.com.br` - Active
- `caixarapido.online` - Active

### Hosted Websites (Shared Hosting plan `u388974772`):
- `bodyharmony.tech` is hosted as an **addon domain** on Hostinger shared hosting.
- Root folder: `/home/u388974772/domains/bodyharmony.tech/public_html`
- Subdomains `api.bodyharmony.com.br`, `app.bodyharmony.com.br`, `stream.bodyharmony.com.br` are also hosted on this plan.

---

## 2. DNS Analysis for `bodyharmony.tech`
The active DNS records in Hostinger for `bodyharmony.tech` reveal a dual-routing configuration (IPv4 vs. IPv6):

| Name | Type | Content | Target Service |
|---|---|---|---|
| `@` (Root) | **A** | `2.25.156.25` | New CRM (VPS) |
| `@` (Root) | **AAAA** | `2a02:4780:75:976d::1` | **Old CRM (Hostinger Shared Hosting)** |
| `crm` | **A** | `2.25.156.25` | New CRM (VPS) |
| `*` (Wildcard) | **A** | `2.25.156.25` | New CRM (VPS) |
| `ftp` | **A** | `45.152.44.244` | Hostinger Shared Hosting |

### Why is the old CRM still accessible at `https://bodyharmony.tech/`?
1. **IPv6 Routing Conflict:** The root domain `@` has an **AAAA record** pointing to the IPv6 address of the Hostinger shared hosting server (`2a02:4780:75:976d::1`). Any browser/device that resolves DNS using IPv6 will bypass the VPS IPv4 (`2.25.156.25`) and connect directly to the Hostinger shared hosting server where the old CRM site is active.
2. **Missing VPS Nginx Configuration:** The Nginx server on the VPS (config: `/etc/nginx/sites-enabled/crm`) only has `server_name` blocks defined for `crm.bodyharmony.tech`, `crm-api.bodyharmony.tech`, `auth-api.bodyharmony.tech`, and `api.bodyharmony.tech`. It does not contain any block for the root domain `bodyharmony.tech`. Therefore, even if a request reaches the VPS via IPv4, Nginx does not know how to handle it.

---

## 3. Recommended Remediation Plan
To deprecate the old CRM and point the root domain to the new environment:

1. **Delete AAAA Record:** In the Hostinger DNS zone manager, delete the AAAA record pointing to `2a02:4780:75:976d::1`.
2. **Nginx Configuration:** If the root domain `bodyharmony.tech` should redirect to `crm.bodyharmony.tech` or serve the frontend, add a corresponding server block in `/etc/nginx/sites-enabled/crm` on the VPS.
3. **Verify Propagation:** Wait for DNS cache to clear and verify that `https://bodyharmony.tech/` resolves to the VPS.

---

## 4. Routing Actions

```yaml
routing_actions:
  - finding: "Conflicting IPv6 AAAA record for bodyharmony.tech points to Hostinger shared hosting instead of VPS"
    target_doc: "docs/specs/tenant-isolation-auth.md"
    status: pending
    owner: "unassigned"
```
