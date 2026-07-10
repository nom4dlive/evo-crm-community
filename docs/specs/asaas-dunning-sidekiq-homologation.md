---
title: Asaas Dunning Enforcement & Sidekiq Cron Resiliance
status: shipped
primary_domain: financial
secondary_domains: [billing, auth]
created: 2026-07-10
applies_to: evo-billing-service
adr_ref: docs/adr/ADR-003-billing-service-architecture.md
file_relationship: EXTENDS docs/specs/financial-management.md
---

# Spec: Asaas Dunning Enforcement & Sidekiq Cron Resiliance

## 1. Goal
Ensure the automatic suspension of delinquent accounts whose grace period has expired, using a daily cron worker (`DailySubscriptionEnforcementJob`) that calls the authentication service to block login access and cancels the local subscription.

---

## 2. Acceptance Criteria (AC)

### AC-01 — Daily Cron Schedule
- The `DailySubscriptionEnforcementJob` must run automatically every day at 03:00 UTC (configured in Sidekiq Scheduler).
- The worker executes inside the `:billing` Sidekiq queue.

### AC-02 — Delinquent Target Selection
- The job must look up subscriptions that meet both criteria:
  - `status == "past_due"`
  - `grace_period_ends_at < Time.current` (expired grace period).
- The query must run unscoped (`Subscription.unscoped`) to scan all database records across all tenants.

### AC-03 — Authenticated S2S Suspension API Call
- For each expired subscription, the worker must call:
  `POST #{EVO_AUTH_INTERNAL_URL}/api/v1/internal/accounts/#{account_id}/suspend`
- The request must carry the `Authorization: Bearer #{INTERNAL_API_SECRET}` header.
- The call must timeout after 5 seconds of opening connection or 10 seconds of reading.

### AC-04 — Local Subscription Cancellation
- If the suspension API call responds with success (`200 OK` or `2xx`), update the local `Subscription`:
  - `status = "canceled"`
  - `canceled_at = Time.current`
- The database write must be scoped to the target tenant using `Current.account_id = subscription.account_id` temporarily.

### AC-05 — Failure Isolation & Sidekiq Retries
- If the S2S suspension call fails (returns non-2xx or raises a connection error), the job must log the error and propagate the failure.
- The subscription status must remain `past_due` (not canceled) to ensure it is retried in subsequent runs.

---

## 3. Non-goals
- In-app notice customization (handled by frontend-auth login views).

---

## 4. Constraints
- **C-01 — Security**: Never print or log `INTERNAL_API_SECRET` in application logs.
- **C-02 — DB Isolation**: Dunning job operates directly on the billing database only.

---

## 5. Domain Decisions
- [DECISION] Perform dunning calculations unscoped at the database query level to ensure efficient batch operations, but set `Current.account_id` before writing back to maintain multi-tenant validation compliance.
- [TRADEOFF] We cancel the subscription locally only AFTER the S2S suspension completes to prevent state mismatch where a user remains active in `evo-auth` but canceled in `evo-billing`.
