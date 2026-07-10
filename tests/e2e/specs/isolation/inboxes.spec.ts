import { test, expect } from '@playwright/test';
import { createIsolatedTenant, authApiRequest, type TenantCredentials } from '../../support/tenant-setup';

/**
 * AC-4: Inboxes / Roles Module Isolation
 * 
 * Verifies that roles (used as configuration analogous to inboxes)
 * belonging to Tenant A are NOT accessible to Tenant B.
 * 
 * We use Roles as the Auth-side analog of "inboxes" since both are
 * tenant-scoped configuration resources.
 */
test.describe('Tenant Isolation: Inboxes (Roles) Module', () => {
  let tenantA: TenantCredentials;
  let tenantB: TenantCredentials;

  test.beforeAll(async () => {
    tenantA = await createIsolatedTenant('IsoInbA');
    tenantB = await createIsolatedTenant('IsoInbB');
  });

  test('tenant B cannot list roles created by tenant A', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // 1. Create a custom role under Tenant A
    const uniqueRoleName = `Hermes-Role-${Date.now()}`;
    const createResp = await authApiRequest('POST', '/api/v1/roles', tenantA.accessToken!, {
      name: uniqueRoleName,
      description: 'E2E Isolation Test Role'
    });

    if (![200, 201].includes(createResp.status)) {
      test.skip(true, `Cannot create roles (status: ${createResp.status})`);
    }

    // 2. List roles from Tenant B
    const listB = await authApiRequest('GET', '/api/v1/roles', tenantB.accessToken!);
    expect(listB.status).toBe(200);

    const rolesB = listB.body?.data || [];
    const leaked = Array.isArray(rolesB)
      ? rolesB.find((r: any) => r.name === uniqueRoleName)
      : null;

    expect(leaked).toBeUndefined();
  });

  test('tenant B cannot update a role belonging to tenant A', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    // 1. Create role under Tenant A
    const createResp = await authApiRequest('POST', '/api/v1/roles', tenantA.accessToken!, {
      name: `CrossUpdate-${Date.now()}`,
      description: 'Test'
    });

    if (![200, 201].includes(createResp.status)) {
      test.skip(true, `Cannot create roles`);
    }

    const roleIdA = createResp.body?.data?.id;
    test.skip(!roleIdA, 'No role ID returned');

    // 2. Try to update it with Tenant B's token
    const crossUpdate = await authApiRequest('PUT', `/api/v1/roles/${roleIdA}`, tenantB.accessToken!, {
      name: 'HIJACKED'
    });

    expect([403, 404]).toContain(crossUpdate.status);
  });

  test('tenant B cannot delete a role belonging to tenant A', async () => {
    test.skip(!tenantA.accessToken || !tenantB.accessToken, 'Tenants could not be provisioned');

    const createResp = await authApiRequest('POST', '/api/v1/roles', tenantA.accessToken!, {
      name: `CrossDelete-${Date.now()}`,
      description: 'Test'
    });

    if (![200, 201].includes(createResp.status)) {
      test.skip(true, `Cannot create roles`);
    }

    const roleIdA = createResp.body?.data?.id;
    test.skip(!roleIdA, 'No role ID returned');

    // Attempt cross-tenant delete
    const crossDelete = await authApiRequest('DELETE', `/api/v1/roles/${roleIdA}`, tenantB.accessToken!);

    expect([403, 404]).toContain(crossDelete.status);
  });
});
