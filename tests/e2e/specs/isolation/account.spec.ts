import { test, expect } from '@playwright/test';
import { createIsolatedTenant, authApiRequest, type TenantCredentials } from '../../support/tenant-setup';

/**
 * AC-1: Account Settings Isolation
 * 
 * Verifies that updating account settings (name) for Tenant A
 * does NOT affect the account settings visible to Tenant B.
 * 
 * Strategy: API-level — register two tenants, update account name
 * for Tenant A via the Auth API, then verify Tenant B's account
 * name remains unchanged.
 */
test.describe('Tenant Isolation: Account Settings', () => {
  let tenantA: TenantCredentials;
  let tenantB: TenantCredentials;

  test.beforeAll(async () => {
    tenantA = await createIsolatedTenant('IsoAcctA');
    tenantB = await createIsolatedTenant('IsoAcctB');
  });

  test('updating account name for tenant A does not change tenant B account name', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // 1. Get Tenant B's original account info
    const beforeB = await authApiRequest('GET', '/api/v1/account', tenantB.accessToken!);
    const originalNameB = beforeB.body?.data?.name || beforeB.body?.data?.account?.name;

    // 2. Update Tenant A's account name
    const newNameA = 'IsoAcctA - Updated by Hermes';
    await authApiRequest('PUT', '/api/v1/account', tenantA.accessToken!, {
      account: { name: newNameA }
    });

    // 3. Re-read Tenant B's account — must be unchanged
    const afterB = await authApiRequest('GET', '/api/v1/account', tenantB.accessToken!);
    const currentNameB = afterB.body?.data?.name || afterB.body?.data?.account?.name;

    expect(currentNameB).toBe(originalNameB);
    expect(currentNameB).not.toBe(newNameA);
  });

  test('tenant B cannot read tenant A account via direct ID', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');
    test.skip(!tenantA.accountId, 'Tenant A has no account_id');

    // Attempt to access Tenant A's account using Tenant B's token
    const crossRead = await authApiRequest(
      'GET',
      `/api/v1/accounts/${tenantA.accountId}`,
      tenantB.accessToken!
    );

    // Must be 404 (not found in tenant B's scope) or 403 (forbidden)
    expect([403, 404]).toContain(crossRead.status);
  });
});
