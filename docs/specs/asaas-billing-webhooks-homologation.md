---
title: Asaas Webhook Ingress & Idempotency Homologation
status: shipped
primary_domain: financial
secondary_domains: [billing, auth]
created: 2026-07-10
applies_to: evo-billing-service
adr_ref: docs/adr/ADR-003-billing-service-architecture.md
file_relationship: EXTENDS docs/specs/financial-management.md
---

# Spec: Asaas Webhook Ingress & Idempotency Homologation

## 1. Goal
Configure and validate the Asaas Webhook ingress (`POST /billing/webhooks/asaas`), ensuring secure token verification (`asaas-access-token`), idempotency processing by `event_id`, and correct dispatch of payment confirmation events to resume suspended subscriptions.

---

## 2. Acceptance Criteria (AC)

### AC-01 — HMAC/Token Signature Verification
- The endpoint `POST /billing/webhooks/asaas` must intercept incoming requests.
- Verify the header `asaas-access-token` against `ENV["ASAAS_WEBHOOK_SECRET"]`.
- Return `401 Unauthorized` if the token is missing or incorrect.
- Skip verification only in `Rails.env.test?` when `ENV["ASAAS_WEBHOOK_SECRET"]` is blank.

### AC-02 — Event Idempotency
- Before processing any event, check the `asaas_webhook_events` table for a record with the same `event_id`.
- If a record exists and was already processed, return `200 OK` with `{ "status": "already_processed" }` immediately, without repeating side-effects.
- Log raw payloads in `asaas_webhook_events` before processing.

### AC-03 — Webhook Event Mapping & Actions
- **`PAYMENT_CONFIRMED` / `PAYMENT_RECEIVED`**:
  - Update `Payment` status to `"confirmed"`.
  - Update linked `Invoice` status to `"paid"`.
  - Set `Subscription` status to `"active"` and clear `grace_period_ends_at`.
  - Send internal S2S request to `evo-auth` to unsuspend the account if it was previously past due.
- **`PAYMENT_OVERDUE`**:
  - Update `Payment` status to `"failed"`.
  - Mark corresponding `ContactCharge` as overdue.
- **`PAYMENT_DELETED` / `PAYMENT_REFUNDED`**:
  - Update `Payment` status to `"refunded"`.
  - Cancel corresponding `ContactCharge`.

### AC-04 — Test Coverage
- RSpec requests spec validating HMAC authentication (authorized/unauthorized).
- RSpec requests spec validating idempotency (second identical request is no-op).
- RSpec requests spec verifying state transitions for confirmations and overdues.

---

## 3. Non-goals
- Re-processing of webhook events via administrative UI in this phase.

---

## 4. Constraints
- **C-01 — Token Security**: Webhook secret must never be committed.
- **C-02 — Loose Coupling**: The webhook processing must not trigger synchronous requests back to Asaas.

---

## 5. Domain Decisions
- [DECISION] Log raw event payloads first to ensure we have record of webhook transmission even if processing fails.
- [CONSTRAINT] The webhook controller must verify signature using secure time-constant comparison (`ActiveSupport::SecurityUtils.secure_compare`).
