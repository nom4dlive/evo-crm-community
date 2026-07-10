---
title: Asaas Customer Sync & Document Validation
status: draft
primary_domain: financial
secondary_domains: [billing, auth]
created: 2026-07-10
applies_to: evo-billing-service
adr_ref: docs/adr/ADR-003-billing-service-architecture.md
file_relationship: EXTENDS docs/specs/financial-management.md
---

# Spec: Asaas Customer Sync & Document Validation

## 1. Goal
Implement and validate the synchronization of Customers between Evolution CRM and the Asaas API, introducing robust document normalization (CPF/CNPJ) and error handling to handle API-level validation failures gracefully.

---

## 2. Acceptance Criteria (AC)

### AC-01 — Document Normalization
Before sending any customer creation payload to Asaas, the billing service must strip all punctuation (dots, hyphens, slashes, spaces) from the CPF or CNPJ. 
- CPF must be exactly 11 digits.
- CNPJ must be exactly 14 digits.
- Payload containing other lengths or letters must return `422 Unprocessable Entity` immediately without calling the Asaas API.

### AC-02 — API Error Handling & Mapping
If the Asaas API returns a validation error (e.g., code `invalid_cpf_cnpj` or `invalid_phone`):
- The controller must rescue the `AsaasClient::ApiError`.
- It must map the error and respond to the client with `422 Unprocessable Entity` (or `502 Bad Gateway` if the connection fails) and a clear, structured JSON error response.
- The local database record must NOT be saved (transactional integrity).

### AC-03 — Multi-Tenant Isolation
- The `Customer` model must enforce `default_scope { where(account_id: Current.account_id) }`.
- A request to create or query a customer must strictly use `Current.account_id`.
- The controller must reject requests where `Current.account_id` is missing or nil with `401 Unauthorized` or `500 Internal Server Error`.

### AC-04 — Test Coverage
- Request specs verifying customer creation with valid sandbox payloads (returning 201 Created).
- Request specs verifying error propagation when Asaas returns a validation error (returning 422 Unprocessable Entity).
- Request specs verifying multi-tenant scoping.

---

## 3. Non-goals
- Synchronization of customer address details (deferred to a profile-sync spec).
- Bank slip/invoice split setup for subaccounts in this phase.

---

## 4. Constraints
- **C-01 — Security**: Do not hardcode or log `ASAAS_API_KEY` or any credentials.
- **C-02 — DB Isolation**: The Customer table must remain strictly in `evo_billing_{env}` database.

---

## 5. API / Data Contract

### POST /api/v1/customers
**Request Body:**
```json
{
  "customer": {
    "contact_id": 12,
    "name": "João Silva",
    "cpf_cnpj": "123.456.789-00",
    "email": "joao@example.com",
    "phone": "(11) 99999-9999"
  }
}
```

**Response (201 Created):**
```json
{
  "data": {
    "id": 1,
    "contact_id": 12,
    "name": "João Silva",
    "cpf_cnpj": "12345678900",
    "asaas_customer_id": "cus_000005741290",
    "created_at": "2026-07-10T14:35:00Z"
  }
}
```

**Response (422 Unprocessable Entity - Validation Error):**
```json
{
  "error": "asaas_validation_error",
  "message": "Asaas API validation failed",
  "details": [
    {
      "code": "invalid_cpf_cnpj",
      "description": "O CPF ou CNPJ informado é inválido."
    }
  ]
}
```

---

## 6. Domain Decisions
- [DECISION] We normalization CPF/CNPJ to digits-only locally before validation to prevent sending malformed strings that cause redundant API calls to Asaas.
- [TRADEOFF] We rescue and map Asaas validation errors directly to 422 Unprocessable Entity to match standard API behavior, even though the error originates from an external service.
- [CONSTRAINT] A transaction boundary must wrap both the Asaas client API call and the local `Customer.save` so that a local record is never saved if the Asaas registration fails.
