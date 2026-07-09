# Project Current State (vNext)

> This is the **Single Source of Truth (SSoT)** — global project state that auto-updates
> via `/ship`. You don't edit this manually; placeholders fill in as you complete work.

- **Project Intent**: [Describe your project in one line]
- **Project Name**: (set by /app-init)
- **Core Guardrails**:
  - Correctness first: No claim of completion without evidence.
  - Small & reversible: Prioritize small, reversible changes; avoid unauthorized refactoring.
  - Document-first: Core logic or structural changes require a Spec/ADR first.
  - Handoff gate: Non-`tiny-fix` tasks must produce a traceable handoff summary.
- **System Map**:
  - Global SSoT: `.agentcortex/context/current_state.md`
  - Task Isolation: `.agentcortex/context/work/<worklog-key>.md`
  - Active Work Log Path: derive <worklog-key> from the raw branch name using filesystem-safe normalization before any gate checks.
  - Workflows & Policies: `.agent/workflows/*.md`, `.agent/rules/*.md`
- **Last Updated**: 2026-07-09T22:24:00Z
- **Last Verified**: 2026-07-09
- **Update Sequence**: 14
- **ADR Index**: 
  - docs/adr/ADR-001-tenant-routing.md: Custom Domain and Subdomain Routing · applies_to: evo-auth-service-community, nginx
  - docs/adr/ADR-002-tenant-isolation-auth.md: Multi-Tenant Scoping and Security Isolation · applies_to: evo-auth-service-community, evo-ai-core-service-community, evo-ai-processor-community
- **Active Backlog**: docs/specs/_product-backlog.md
- **Spec Index** (project specs at `docs/specs/`):
  - docs/specs/stabilization.md: Environment Stabilization and Error Resolution · status: shipped · applies_to: evo-flow-community, nginx
  - docs/specs/tenant-isolation-auth.md: Multi-Tenant Scoping and Security Isolation · status: shipped · applies_to: evo-auth-service-community, evo-ai-core-service-community, evo-ai-processor-community
- **Canonical Commands**:
  - `/spec-intake`: Import external specs (from other LLMs, documents, or natural language). Handles large product specs via decomposition. Runs before `/bootstrap`.
  - `/bootstrap`: Task initialization & classification freeze.
  - `/plan`: Define target files, steps, risks, and rollback.
  - `/implement`: Execute implementation only when `IMPLEMENTABLE`.
  - `/review`: Check AC alignment & scope creep.
  - `/test`: Report test coverage via Test Skeleton.
  - `/handoff`: Output resumable state summary (mandatory for non-tiny-fix).
  - `/decide`: Record key decisions with reasoning to prevent cross-session re-derivation.
  - `/test-classify`: Auto-select test depth and evidence format based on task classification.
  - `/ship`: Consolidate evidence and update/archive state.
  - `ask-openrouter`: [OPTIONAL] External model delegation. See `.agent/workflows/ask-openrouter.md`.
  - `codex-cli`: [OPTIONAL] Codex CLI delegation. See `.agent/workflows/codex-cli.md`.
  - `claude-cli`: [OPTIONAL] Claude CLI delegation. See `.agent/workflows/claude-cli.md`.
  - `ask-local`: [OPTIONAL] Local-model (OpenAI-compatible endpoint) delegation. See `.agent/workflows/ask-local.md`.
- **References**:
  - `AGENTS.md`
  - `.agent/rules/engineering_guardrails.md`
  - `.agent/rules/state_machine.md`
  - `.agentcortex/docs/CODEX_PLATFORM_GUIDE.md`
  - `.agentcortex/docs/guides/token-governance.md` *(manual-only)*
  - `.agentcortex/docs/guides/context-budget.md` *(manual-only)*

> [!NOTE]
> This file is the Single Source of Truth for global project context only.
> Do not store per-task progress here; write progress to `.agentcortex/context/work/<worklog-key>.md`.

## Global Lessons (AI Error Pattern Registry)
>
> Structured format:
> `- [Category: <tag>][Severity: <HIGH|MEDIUM|LOW>][Trigger: <normalized-trigger>] <lesson>`
>
> `/implement` reviews active HIGH-severity lessons before code changes. `/retro` may append new structured entries via guarded write.

(none yet)

## Ship History

### Ship-main-2026-07-09-hermes-e2e-roles
- Feature shipped: Resolved roles (inboxes) tenant isolation gap in evo-auth service by adding account_id to roles table, applying dynamic default scope, and fixing exception handling precedence.
- Tests: Pass

### Ship-main-2026-07-09-hermes-e2e
- Feature shipped: End-to-end API-level Playwright tests created and verified for account, user, contact, and inbox tenant isolation on the Podman Desktop container stack.
- Tests: Pass

### Ship-main-2026-07-09-tenant-isolation
- Feature shipped: Fixed the multi-tenant isolation leak in Auth API where `StandardError` blocked `RecordNotFound` exceptions, and enforced strict TDD isolation checks across both evo-auth and evo-crm services.
- Tests: Pass

### Ship-main-2026-07-09-testes-vps
- Feature shipped: Validated real tests on VPS for Tenant isolation. Bootstrapped testevps tenant via SSH script, generated JWT from evo-auth, and successfully routed and validated tenant isolation on both CRM (Go) and Processor (Python) endpoints via Traefik/Nginx.
- Tests: Pass

### Ship-main-2026-07-08-random-tenant-provisioning
- Feature shipped: Interactively provisioned a new random tenant (`tenant-4829`) on the VPS environment and verified database schema insertion (Account and User tables) and successful OAuth2 login auth handshake with HTTP 200 OK.
- Tests: Pass

### Ship-main-2026-07-08-remediation
- Feature shipped: Resolved all multi-tenant isolation database schema and middleware gaps in the community build of the Go core service (activated CommunityTenantPlugin and declared tenant_id column) and Python processor service (added tenant_id column via Alembic migration). Fixed Redis SSL connection parameter mismatch and EvoAuth exception handler request parameters. Verified 17/17 integration tests passing successfully on the VPS.
- Tests: Pass

### Ship-main-2026-07-08-api-fixes
- Feature shipped: Resolved the database migration timestamp collision by renaming `20260706200000_add_account_id_to_core_tables.rb` to `20260706200005_add_account_id_to_core_tables.rb` in `evo-crm` submodule, and fixed setup_tenant.rb and bin/create-tenant.sh to confirm users and search roles by their exact keys.
- Tests: Pass

### Ship-main-2026-07-08
- Feature shipped: Resolved immediate governance issues by referencing the routing index and adding safety-floor comment markers in `AGENTS.md`, and adding YAML frontmatter status to `docs/specs/tenant-isolation-auth.md`. Also marked completed backlog items (ADR frontmatter, routing index reference, spec status, safety markers) as Shipped.
- Tests: Pass

### Ship-main-2026-07-08-multi-tenant-security
- Feature shipped: Scoping and stamping tenant context across Rails (evo-auth), Go (evo-core), and Python (evo-processor). Updated UserSerializer, AgentBuilder, Gin/GORM community scoping plugin, and FastAPI/SQLAlchemy event listeners. Verified via Rails request specs and rebuilt microservices images on VPS.
- Tests: Pass

### Ship-main-2026-07-07-tenant-helper
- Feature shipped: Criação do assistente bin/create-tenant.sh e testes de validação TDD, ajustado para target do container evo-auth.
- Tests: Pass

### Ship-main-2026-07-07
- Feature shipped: Injeção de variáveis de ambiente do EvoFlow client na VPS, resolvendo o erro 500 no endpoint de segmentos do Rails CRM.
- Tests: Pass

- **2026-07-07**: Deploy do serviço evo-flow (NestJS) na VPS, correção do Nginx gateway (upstream flow_service para jornadas/campanhas), resolução dos conflitos de porta do Traefik, e criação da documentação de Single Source of Truth (MULTI_TENANT_MAP.md, DESCOBERTAS_CONSOLIDADAS.md, DEPLOYMENT_GUIDE.md).
- **2026-07-07**: Correção de TLS (certificado SSL expandido para api.bodyharmony.tech) e correção do healthcheck do container evo-auth (shebang CRLF convertido para LF). Tenant Body Harmony configurado e credenciais de superadmin e suporte provisionadas.
- **2026-07-06**: Entrega MVP (5 rodadas). `auth-api` configurado and `evolution-go` (crm-api) licensed. Ambiente legado removido. Infraestrutura rodando no Traefik (porta 4000, 3001). Cliente Body Harmony provisionado com superadmin.
