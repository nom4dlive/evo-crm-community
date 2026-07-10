import { test, expect, request as playwrightRequest } from '@playwright/test';

/**
 * Tenant Setup Utility for E2E Isolation Tests
 * 
 * Creates isolated tenants via the Auth API's registration endpoint.
 * Each call provisions a new user + account pair for cross-tenant testing.
 * 
 * Environment Variables:
 *   AUTH_API_URL - Base URL for auth service (default: http://localhost:3001)
 *   BASE_URL    - Base URL for CRM API (default: http://localhost:4000)
 */

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

export interface TenantCredentials {
  userId: string;
  email: string;
  password: string;
  tenantName: string;
  accessToken: string | null;
  accountId: string | null;
}

const AUTH_BASE = process.env.AUTH_API_URL || 'http://localhost:3001';
const CRM_BASE = process.env.BASE_URL || 'http://localhost:4000';

function provisionTenantInDb(email: string, tenantName: string, slug: string) {
  const rubyCode = `
user = User.find_by(email: '${email}')
if user
  account = Account.create!(name: '${tenantName}', slug: '${slug}', status: 'active')
  user.update!(account: account)
  Tenant.create!(name: '${tenantName}', subdomain: '${slug}', status: 'active', plan: 'enterprise', owner: user)
  role = Role.find_by(key: 'super_admin') || Role.find_by(key: 'account_owner') || Role.first
  UserRole.find_or_create_by!(user: user, role: role, account_id: account.id)
  puts "SUCCESS: #{account.id}"
else
  puts "ERROR: User not found"
end
`.trim();

  const tmpFileName = `e2e_setup_${slug}.rb`;
  // Path on the host relative to this file
  const hostTmpPath = path.resolve(__dirname, '../../../evo-auth-service-community/tmp', tmpFileName);
  
  // Ensure tmp dir exists
  fs.mkdirSync(path.dirname(hostTmpPath), { recursive: true });
  fs.writeFileSync(hostTmpPath, rubyCode);

  const containerCmd = `bundle exec rails runner tmp/${tmpFileName}`;
  let output = '';

  try {
    output = execSync(`podman compose exec -T evo-auth ${containerCmd}`, { encoding: 'utf8' });
  } catch {
    try {
      output = execSync(`docker compose exec -T evo-auth ${containerCmd}`, { encoding: 'utf8' });
    } catch (e: any) {
      console.warn(`[tenant-setup] DB provisioning failed: ${e.message}`);
    }
  } finally {
    try {
      fs.unlinkSync(hostTmpPath);
    } catch {}
  }

  const match = output.match(/SUCCESS: ([a-f0-9-]+)/);
  return match ? match[1] : null;
}

/**
 * Register a new user via the Auth API.
 * Returns credentials including the access token for subsequent API calls.
 */
export async function createIsolatedTenant(tenantName: string): Promise<TenantCredentials> {
  const suffix = Math.random().toString(36).substring(2, 8);
  const slug = `iso-${suffix}`;
  const email = `e2e-${suffix}@${tenantName.toLowerCase().replace(/\s+/g, '')}.test`;
  const password = 'Password123!';

  const context = await playwrightRequest.newContext();

  // 1. Register the user
  const registerResponse = await context.post(`${AUTH_BASE}/api/v1/auth/register`, {
    data: {
      name: `${tenantName} Admin`,
      email,
      password,
      password_confirmation: password
    }
  });

  let userId = '';
  let accountId: string | null = null;

  if (registerResponse.ok()) {
    const body = await registerResponse.json();
    userId = body.data?.user?.id || '';
  } else {
    const errorText = await registerResponse.text();
    console.warn(`[tenant-setup] Registration failed (status: ${registerResponse.status()}): ${errorText}`);
  }

  // 2. Provision Account, Tenant, and Role in Database
  accountId = provisionTenantInDb(email, tenantName, slug);

  // 3. Login to get access token
  const loginResponse = await context.post(`${AUTH_BASE}/api/v1/auth/login`, {
    data: { email, password }
  });

  let accessToken: string | null = null;

  if (loginResponse.ok()) {
    const loginBody = await loginResponse.json();
    accessToken = loginBody.data?.token?.access_token || loginBody.data?.access_token || null;
  } else {
    console.warn(`[tenant-setup] Login failed (status: ${loginResponse.status()})`);
  }

  await context.dispose();

  return { userId, email, password, tenantName, accessToken, accountId };
}

/**
 * Make an authenticated API request to the Auth service.
 */
export async function authApiRequest(
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  path: string,
  token: string,
  data?: Record<string, unknown>
) {
  const context = await playwrightRequest.newContext();
  const response = await context.fetch(`${AUTH_BASE}${path}`, {
    method,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    data
  });
  const body = await response.json().catch(() => null);
  await context.dispose();
  return { status: response.status(), body };
}

/**
 * Make an authenticated API request to the CRM service.
 */
export async function crmApiRequest(
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  path: string,
  token: string,
  data?: Record<string, unknown>
) {
  const context = await playwrightRequest.newContext();
  const response = await context.fetch(`${CRM_BASE}${path}`, {
    method,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    data
  });
  const body = await response.json().catch(() => null);
  await context.dispose();
  return { status: response.status(), body };
}
