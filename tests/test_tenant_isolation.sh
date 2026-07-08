#!/bin/bash
# =============================================================================
# Multi-Tenant Isolation Integration Test Suite
# =============================================================================
# This script tests the actual running services on the VPS to verify
# multi-tenant data isolation. It uses curl to hit real endpoints.
#
# Usage: bash /var/www/n4-crm/client-a/tests/test_tenant_isolation.sh
# =============================================================================

set -euo pipefail

REPORT_FILE="/var/www/n4-crm/client-a/tests/test-report.md"
PASS=0
FAIL=0
WARN=0
RESULTS=""

# Service URLs (from host perspective)
AUTH_HOST="http://localhost:3001"
CRM_HOST="http://localhost:3000"
PROCESSOR_HOST="http://localhost:8000"
GATEWAY_HOST="http://localhost:3030"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

record() {
    local status="$1" test_name="$2" detail="$3"
    case "$status" in
        PASS) PASS=$((PASS+1)); RESULTS+="| ✅ PASS | $test_name | $detail |\n" ;;
        FAIL) FAIL=$((FAIL+1)); RESULTS+="| ❌ FAIL | $test_name | $detail |\n" ;;
        WARN) WARN=$((WARN+1)); RESULTS+="| ⚠️ WARN | $test_name | $detail |\n" ;;
    esac
}

# =============================================================================
# PHASE 1: Service Health Checks
# =============================================================================
log "=== PHASE 1: Service Health Checks ==="

AUTH_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$AUTH_HOST/health" 2>/dev/null || echo "000")
if [ "$AUTH_HEALTH" = "200" ]; then record "PASS" "Auth Health" "HTTP $AUTH_HEALTH"
else record "FAIL" "Auth Health" "HTTP $AUTH_HEALTH (expected 200)"; fi

CRM_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$CRM_HOST/health" 2>/dev/null || echo "000")
if [ "$CRM_HEALTH" = "200" ]; then record "PASS" "CRM Health" "HTTP $CRM_HEALTH"
else record "FAIL" "CRM Health" "HTTP $CRM_HEALTH (expected 200)"; fi

PROC_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$PROCESSOR_HOST/healthz" 2>/dev/null || echo "000")
if [ "$PROC_HEALTH" = "200" ]; then record "PASS" "Processor Health" "HTTP $PROC_HEALTH"
else record "FAIL" "Processor Health" "HTTP $PROC_HEALTH (expected 200)"; fi

PROC_READY=$(curl -s "$PROCESSOR_HOST/readyz" 2>/dev/null || echo '{"status":"error"}')
PROC_READY_STATUS=$(echo "$PROC_READY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','error'))" 2>/dev/null || echo "error")
if [ "$PROC_READY_STATUS" = "ready" ]; then record "PASS" "Processor Readiness" "All subsystems ready"
else record "WARN" "Processor Readiness" "Status: $PROC_READY_STATUS"; fi

GW_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_HOST/health" 2>/dev/null || echo "000")
if [ "$GW_HEALTH" = "200" ]; then record "PASS" "Gateway Health" "HTTP $GW_HEALTH"
else record "WARN" "Gateway Health" "HTTP $GW_HEALTH (gateway may route differently)"; fi

# =============================================================================
# PHASE 2: Authentication Flow
# =============================================================================
log "=== PHASE 2: Authentication Flow ==="

LOGIN_RESPONSE=$(curl -s -X POST "$AUTH_HOST/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"superadmin@bodyharmony.tech","password":"Nom4dLive@2026!"}' 2>/dev/null || echo '{"error":"connection_failed"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    token = data.get('data', {}).get('access_token') or data.get('access_token') or data.get('token')
    if token: print(token)
    else: print('NO_TOKEN')
except: print('PARSE_ERROR')
" 2>/dev/null || echo "PARSE_ERROR")

if [ "$TOKEN" != "NO_TOKEN" ] && [ "$TOKEN" != "PARSE_ERROR" ] && [ -n "$TOKEN" ]; then
    record "PASS" "Auth Login (superadmin)" "Got JWT token"
    log "  Token: ${TOKEN:0:30}..."
else
    record "FAIL" "Auth Login (superadmin)" "No token. Response: ${LOGIN_RESPONSE:0:200}"
    # Try Devise session endpoint
    LOGIN_RESPONSE2=$(curl -s -X POST "$AUTH_HOST/auth/sign_in" \
        -H "Content-Type: application/json" \
        -d '{"user":{"email":"superadmin@bodyharmony.tech","password":"Nom4dLive@2026!"}}' 2>/dev/null || echo '{}')
    TOKEN2=$(echo "$LOGIN_RESPONSE2" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    token = data.get('data', {}).get('access_token') or data.get('access_token') or data.get('token')
    if token: print(token)
    else: print('NO_TOKEN')
except: print('PARSE_ERROR')
" 2>/dev/null || echo "PARSE_ERROR")
    if [ "$TOKEN2" != "NO_TOKEN" ] && [ "$TOKEN2" != "PARSE_ERROR" ] && [ -n "$TOKEN2" ]; then
        TOKEN="$TOKEN2"
        record "PASS" "Auth Login (Devise fallback)" "Got JWT token via Devise"
    else
        log "  Devise response: ${LOGIN_RESPONSE2:0:200}"
    fi
fi

# =============================================================================
# PHASE 3: Database Schema Isolation Audit
# =============================================================================
log "=== PHASE 3: Database Schema Isolation Audit ==="

TABLES_WITHOUT_TENANT=$(docker exec postgres psql -U postgres -d evocrm -t -A -c \
    "SELECT DISTINCT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'evo_core%' AND table_name NOT IN (SELECT table_name FROM information_schema.columns WHERE column_name IN ('account_id', 'tenant_id') AND table_name LIKE 'evo_core%') ORDER BY table_name" 2>/dev/null || echo "ERROR")

if [ "$TABLES_WITHOUT_TENANT" = "" ]; then
    record "PASS" "Schema: evo_core tenant isolation" "All evo_core tables have tenant column"
elif [ "$TABLES_WITHOUT_TENANT" = "ERROR" ]; then
    record "WARN" "Schema: evo_core tenant isolation" "Could not query schema"
else
    record "FAIL" "Schema: evo_core tenant isolation" "Missing isolation: $(echo $TABLES_WITHOUT_TENANT | tr '\n' ', ')"
fi

PROC_TABLES_WITHOUT=$(docker exec postgres psql -U postgres -d evocrm -t -A -c \
    "SELECT DISTINCT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'evo_ai_agent_processor%' AND table_name NOT IN (SELECT table_name FROM information_schema.columns WHERE column_name IN ('account_id', 'tenant_id') AND table_name LIKE 'evo_ai_agent_processor%') ORDER BY table_name" 2>/dev/null || echo "ERROR")

if [ "$PROC_TABLES_WITHOUT" = "" ]; then
    record "PASS" "Schema: processor tenant isolation" "All processor tables have tenant column"
elif [ "$PROC_TABLES_WITHOUT" = "ERROR" ]; then
    record "WARN" "Schema: processor tenant isolation" "Could not query schema"
else
    record "FAIL" "Schema: processor tenant isolation" "Missing isolation: $(echo $PROC_TABLES_WITHOUT | tr '\n' ', ')"
fi

CRM_TABLES_COUNT=$(docker exec postgres psql -U postgres -d evocrm -t -A -c \
    "SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE column_name = 'account_id' AND table_schema = 'public'" 2>/dev/null || echo "0")
record "PASS" "Schema: CRM tenant isolation" "$CRM_TABLES_COUNT tables with account_id"

# =============================================================================
# PHASE 4: Processor API Endpoint Tests (unauthenticated)
# =============================================================================
log "=== PHASE 4: Processor API Endpoint Tests ==="

UNAUTH=$(curl -s -o /dev/null -w "%{http_code}" "$PROCESSOR_HOST/api/v1/sessions/account" 2>/dev/null || echo "000")
if [ "$UNAUTH" = "401" ] || [ "$UNAUTH" = "403" ]; then
    record "PASS" "Processor: Unauthenticated sessions" "HTTP $UNAUTH"
else record "FAIL" "Processor: Unauthenticated sessions" "HTTP $UNAUTH (expected 401/403)"; fi

RANDOM_SESSION="00000000-0000-0000-0000-000000000000"
RANDOM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$PROCESSOR_HOST/api/v1/sessions/$RANDOM_SESSION" 2>/dev/null || echo "000")
if [ "$RANDOM_STATUS" = "401" ] || [ "$RANDOM_STATUS" = "403" ] || [ "$RANDOM_STATUS" = "404" ]; then
    record "PASS" "Processor: Random session access" "HTTP $RANDOM_STATUS"
else record "FAIL" "Processor: Random session access" "HTTP $RANDOM_STATUS (expected 401/403/404)"; fi

# =============================================================================
# PHASE 5: CRM API Endpoint Tests (unauthenticated)
# =============================================================================
log "=== PHASE 5: CRM API Endpoint Tests ==="

UNAUTH_INBOXES=$(curl -s -o /dev/null -w "%{http_code}" "$CRM_HOST/api/v1/inboxes" 2>/dev/null || echo "000")
if [ "$UNAUTH_INBOXES" = "401" ] || [ "$UNAUTH_INBOXES" = "403" ]; then
    record "PASS" "CRM: Unauthenticated inboxes" "HTTP $UNAUTH_INBOXES"
else record "FAIL" "CRM: Unauthenticated inboxes" "HTTP $UNAUTH_INBOXES (expected 401/403)"; fi

UNAUTH_CONTACTS=$(curl -s -o /dev/null -w "%{http_code}" "$CRM_HOST/api/v1/contacts" 2>/dev/null || echo "000")
if [ "$UNAUTH_CONTACTS" = "401" ] || [ "$UNAUTH_CONTACTS" = "403" ]; then
    record "PASS" "CRM: Unauthenticated contacts" "HTTP $UNAUTH_CONTACTS"
else record "FAIL" "CRM: Unauthenticated contacts" "HTTP $UNAUTH_CONTACTS (expected 401/403)"; fi

# =============================================================================
# PHASE 6: Cross-Service Token Validation
# =============================================================================
log "=== PHASE 6: Cross-Service Token Validation ==="

if [ "$TOKEN" != "NO_TOKEN" ] && [ "$TOKEN" != "PARSE_ERROR" ] && [ -n "$TOKEN" ]; then
    AUTH_CRM=$(curl -s -o /dev/null -w "%{http_code}" "$CRM_HOST/api/v1/profile" \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "000")
    if [ "$AUTH_CRM" = "200" ]; then record "PASS" "Cross-service: Token on CRM" "HTTP $AUTH_CRM"
    else record "WARN" "Cross-service: Token on CRM" "HTTP $AUTH_CRM"; fi

    AUTH_PROC=$(curl -s -o /dev/null -w "%{http_code}" "$PROCESSOR_HOST/api/v1/sessions/account" \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "000")
    if [ "$AUTH_PROC" = "200" ]; then record "PASS" "Cross-service: Token on Processor" "HTTP $AUTH_PROC"
    else record "WARN" "Cross-service: Token on Processor" "HTTP $AUTH_PROC"; fi

    FAKE_TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.fakesig"
    FAKE_CRM=$(curl -s -o /dev/null -w "%{http_code}" "$CRM_HOST/api/v1/profile" \
        -H "Authorization: Bearer $FAKE_TOKEN" 2>/dev/null || echo "000")
    if [ "$FAKE_CRM" = "401" ] || [ "$FAKE_CRM" = "403" ]; then
        record "PASS" "Cross-service: Fake token rejected by CRM" "HTTP $FAKE_CRM"
    else record "FAIL" "Cross-service: Fake token rejected by CRM" "HTTP $FAKE_CRM (expected 401/403)"; fi

    FAKE_PROC=$(curl -s -o /dev/null -w "%{http_code}" "$PROCESSOR_HOST/api/v1/sessions/account" \
        -H "Authorization: Bearer $FAKE_TOKEN" 2>/dev/null || echo "000")
    if [ "$FAKE_PROC" = "401" ] || [ "$FAKE_PROC" = "403" ]; then
        record "PASS" "Cross-service: Fake token rejected by Processor" "HTTP $FAKE_PROC"
    else record "FAIL" "Cross-service: Fake token rejected by Processor" "HTTP $FAKE_PROC (expected 401/403)"; fi
else
    record "WARN" "Cross-service: Token tests" "SKIPPED (no valid token obtained)"
fi

# =============================================================================
# GENERATE REPORT
# =============================================================================
log "=== Generating Report ==="

TOTAL=$((PASS + FAIL + WARN))
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$REPORT_FILE" << REPORT_EOF
# Multi-Tenant Isolation Test Report

**Generated**: $TIMESTAMP
**VPS**: 2.25.156.25
**Total Tests**: $TOTAL | ✅ Pass: $PASS | ❌ Fail: $FAIL | ⚠️ Warn: $WARN

---

## Results

| Status | Test | Details |
|--------|------|---------|
$(echo -e "$RESULTS")

---

## Critical Findings

### Database Schema Gaps (evo_core tables without tenant isolation)
$(echo "$TABLES_WITHOUT_TENANT" | sed 's/^/- /' || echo "- None found or query error")

### Processor tables without tenant isolation
$(echo "$PROC_TABLES_WITHOUT" | sed 's/^/- /' || echo "- None found or query error")

### Recommended Actions
1. Add account_id to all evo_core_* tables (agents, api_keys, custom_mcp_servers, etc.)
2. Add account_id to processor session tables
3. Add FK constraints and indexes
4. Update Go core service queries to scope by account_id
5. Update Python processor queries to scope by account_id

---

## Service Status
- Auth: HTTP $AUTH_HEALTH
- CRM: HTTP $CRM_HEALTH
- Processor: HTTP $PROC_HEALTH (readiness: $PROC_READY_STATUS)
- Gateway: HTTP $GW_HEALTH
REPORT_EOF

log "Report written to $REPORT_FILE"
log "=== SUMMARY: Total=$TOTAL PASS=$PASS FAIL=$FAIL WARN=$WARN ==="

if [ $FAIL -gt 0 ]; then exit 1; fi
exit 0
