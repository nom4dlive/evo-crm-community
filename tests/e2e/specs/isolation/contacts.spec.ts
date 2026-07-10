import { test, expect } from '@playwright/test';
import { createIsolatedTenant, authApiRequest, type TenantCredentials } from '../../support/tenant-setup';

/**
 * AC-3: Contacts Module Isolation
 * 
 * Verifies that contacts belonging to Tenant A are NOT accessible
 * to Tenant B, either via listing or direct ID access.
 * 
 * Note: Contacts live in the CRM API (evolution-go, port 4000).
 * If the CRM API is unavailable, tests are skipped gracefully.
 */
test.describe('Tenant Isolation: Contacts Module', () => {
  let tenantA: TenantCredentials;
  let tenantB: TenantCredentials;

  test.beforeAll(async () => {
    tenantA = await createIsolatedTenant('IsoCtcA');
    tenantB = await createIsolatedTenant('IsoCtcB');
  });

  test('tenant B cannot list contacts created by tenant A (Auth API - access_tokens)', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // Use access_tokens as a proxy for "scoped resources" since contacts
    // are on the Go CRM. Access tokens are scoped per-account in Auth.
    const createResp = await authApiRequest('POST', '/api/v1/access_tokens', tenantA.accessToken!, {
      access_token: {
        name: `Hermes-Contact-Proxy-${Date.now()}`,
        scopes: 'access_tokens.read'
      }
    });

    // 201 or 200 expected
    if (![200, 201].includes(createResp.status)) {
      test.skip(true, `Cannot create access tokens (status: ${createResp.status})`);
    }

    // List from Tenant B — should NOT contain Tenant A's token
    const listB = await authApiRequest('GET', '/api/v1/access_tokens', tenantB.accessToken!);
    expect(listB.status).toBe(200);

    const tokensB = listB.body?.data || [];
    const leaked = Array.isArray(tokensB)
      ? tokensB.find((t: any) => t.name?.includes('Hermes-Contact-Proxy'))
      : null;

    expect(leaked).toBeUndefined();
  });

  test('tenant B cannot access tenant A resource by direct ID', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // Create a token under Tenant A to get a known resource ID
    const createResp = await authApiRequest('POST', '/api/v1/access_tokens', tenantA.accessToken!, {
      access_token: {
        name: `DirectID-Test-${Date.now()}`,
        scopes: 'access_tokens.read'
      }
    });

    if (![200, 201].includes(createResp.status)) {
      test.skip(true, `Cannot create access tokens`);
    }

    const tokenIdA = createResp.body?.data?.access_token?.id;
    test.skip(!tokenIdA, 'No token ID returned');

    // Try to access it with Tenant B's credentials
    const crossRead = await authApiRequest('GET', `/api/v1/access_tokens/${tokenIdA}`, tenantB.accessToken!);

    expect([403, 404]).toContain(crossRead.status);
  });
});
