# ADR-001: Custom Domain and Subdomain Routing

**Status:** Accepted

## Context
Evolution CRM is transitioning into a multi-tenant platform targeting high-volume WhatsApp automation businesses. A critical requirement for white-labeling and proper tenant isolation is the ability to route traffic to the correct tenant context (the `Account` model) using custom domains (e.g., `crm.client-domain.com`) or system subdomains (e.g., `tenant-slug.evolution-crm.com`). 
Currently, the tenant resolution largely depends on JWT payloads. However, some inbound webhooks, public forms, or unauthenticated pages need context resolved directly from the request host before a user is authenticated.

## Decision
We will map subdomains and custom domains to active Account models at the reverse proxy and application gateway level:
1. **Reverse Proxy (Nginx)**: Nginx will capture the request hostname. A mapping mechanism (or direct application passthrough) will pass the raw `Host` header to the backend. Alternatively, Nginx can set `X-Tenant-Domain` header.
2. **Application Resolution (`EvoAuthConcern`)**: The backend will inspect the `Host` or `X-Tenant-Domain` header and look up the active `Account` record matching the domain/subdomain.
3. **Suspended Accounts**: If the resolved account is suspended or inactive, the application will intercept the request early and return a standard `403 Forbidden` or a branded "Account Suspended" page.
4. **Header Injection**: If resolved successfully, the `EvoAuthConcern` sets `Current.account_id` and continues the request lifecycle.

## Alternatives Considered
- **Path-based routing (e.g., `/t/tenant-slug/`)**: Rejected because it breaks absolute URL references, complicates static asset delivery, and provides a poor white-labeling experience compared to custom domains.
- **Dedicated tenant processes/containers**: Rejected as it defeats the purpose of the monorepo's shared-infrastructure multi-tenancy and drastically increases operational cost.

## Consequences
- **Positive**: True white-label capabilities for tenants. Transparent context resolution for public webhooks and forms.
- **Negative**: Adds complexity to local development (requires modifying `/etc/hosts` or using tools like `dnsmasq`/`lvh.me`). Requires a secure mechanism to manage SSL certificates for custom domains dynamically (e.g., Let's Encrypt / Caddy or an Nginx lua script), which must be implemented in a subsequent phase.
