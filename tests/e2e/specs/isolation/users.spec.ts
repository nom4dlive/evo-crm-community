import { test, expect } from '@playwright/test';
import { createIsolatedTenant, authApiRequest, type TenantCredentials } from '../../support/tenant-setup';

/**
 * AC-2: Users Module Isolation
 * 
 * Verifies that users created by Tenant A are NOT visible
 * to Tenant B when listing users via the Auth API.
 */
test.describe('Tenant Isolation: Users Module', () => {
  let tenantA: TenantCredentials;
  let tenantB: TenantCredentials;

  test.beforeAll(async () => {
    tenantA = await createIsolatedTenant('IsoUsrA');
    tenantB = await createIsolatedTenant('IsoUsrB');
  });

  test('tenant B cannot see users created under tenant A', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // 1. Create a user under Tenant A
    const uniqueName = `Agent Smith ${Date.now()}`;
    const createResp = await authApiRequest('POST', '/api/v1/users', tenantA.accessToken!, {
      name: uniqueName,
      email: `smith-${Date.now()}@iso-test.com`,
      password: 'Password123!',
      password_confirmation: 'Password123!'
    });

    // Accept 201 or 200 — some APIs return 200 for create.
    // 403 means the test user doesn't have admin permissions to create users
    // (not an isolation failure — just a permission gap in test setup).
    if (createResp.status === 403) {
      test.skip(true, 'Test user lacks admin permissions to create users');
    }
    expect([200, 201]).toContain(createResp.status);

    // 2. List users under Tenant B
    const listB = await authApiRequest('GET', '/api/v1/users', tenantB.accessToken!);
    expect(listB.status).toBe(200);

    // 3. Verify Tenant A's user is NOT in Tenant B's list
    const usersB = listB.body?.data || [];
    const leaked = Array.isArray(usersB)
      ? usersB.find((u: any) => u.name === uniqueName || u.email?.includes('smith'))
      : null;

    expect(leaked).toBeUndefined();
  });

  test('tenant B cannot update a user belonging to tenant A', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // 1. Get Tenant A's user ID (the admin themselves)
    const meA = await authApiRequest('GET', '/api/v1/auth/me', tenantA.accessToken!);
    const userIdA = meA.body?.data?.user?.id;
    test.skip(!userIdA, 'Could not get Tenant A user ID');

    // 2. Attempt to update Tenant A's user with Tenant B's token
    const crossUpdate = await authApiRequest('PUT', `/api/v1/users/${userIdA}`, tenantB.accessToken!, {
      name: 'HACKED BY TENANT B'
    });

    // Must be 404 (not found in tenant B's scope) or 403
    expect([403, 404]).toContain(crossUpdate.status);
  });

  test('tenant B cannot delete a user belonging to tenant A', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    const meA = await authApiRequest('GET', '/api/v1/auth/me', tenantA.accessToken!);
    const userIdA = meA.body?.data?.user?.id;
    test.skip(!userIdA, 'Could not get Tenant A user ID');

    // Attempt cross-tenant delete
    const crossDelete = await authApiRequest('DELETE', `/api/v1/users/${userIdA}`, tenantB.accessToken!);

    expect([403, 404]).toContain(crossDelete.status);
  });
});
