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
- **Last Updated**: 2026-07-11T01:36:00Z
- **Last Verified**: 2026-07-11
- **Update Sequence**: 31
- **ADR Index**: 
  - docs/adr/ADR-001-tenant-routing.md: Custom Domain and Subdomain Routing · applies_to: evo-auth-service-community, nginx
  - docs/adr/ADR-002-tenant-isolation-auth.md: Multi-Tenant Scoping and Security Isolation · applies_to: evo-auth-service-community, evo-ai-core-service-community, evo-ai-processor-community
  - docs/adr/ADR-003-billing-service-architecture.md: Financial Management — evo-billing-service Architecture · applies_to: evo-billing-service, evo-auth-service-community, evo-ai-frontend-community, docker-compose.yml, vps-docker-compose.yml, nginx
- **Active Backlog**: docs/specs/_product-backlog.md
- **Spec Index** (project specs at `docs/specs/`):
  - docs/specs/asaas-billing-webhooks-homologation.md: Asaas Webhook Ingress & Idempotency Homologation · status: shipped · applies_to: evo-billing-service
  - docs/specs/asaas-customer-sync-real.md: Asaas Customer Sync & Document Validation · status: shipped · applies_to: evo-billing-service
  - docs/specs/asaas-dunning-sidekiq-homologation.md: Asaas Dunning Enforcement & Sidekiq Cron Resiliance · status: shipped · applies_to: evo-billing-service
  - docs/specs/asaas-nfe-integration.md: Asaas NF-e Integration & Fiscal Reports · status: shipped · applies_to: evo-billing-service, evo-ai-frontend-community
  - docs/specs/financial-management.md: Financial Management Module · status: draft · applies_to: evo-billing-service, evo-auth-service-community, evo-ai-frontend-community
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
  - 'ask-openrouter': [OPTIONAL] External model delegation. See `.agent/workflows/ask-openrouter.md`.
  - 'codex-cli': [OPTIONAL] Codex CLI delegation. See `.agent/workflows/codex-cli.md`.
  - 'claude-cli': [OPTIONAL] Claude CLI delegation. See `.agent/workflows/claude-cli.md`.
  - 'ask-local': [OPTIONAL] Local-model (OpenAI-compatible endpoint) delegation. See `.agent/workflows/ask-local.md`.
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

- [Category: rails-exceptions][Severity: HIGH][Trigger: rescue_from StandardError][prev: GENESIS] Always place the catch-all rescue_from StandardError handler at the very top of the controller file, as Rails checks handlers in reverse order of definition.
## Ship History

### Ship-quick-win-financial-ui-fixes-2026-07-11
- Feature shipped: Integração dos botões de navegação no menu lateral para todas as telas financeiras (Minha Assinatura, Faturas, Cobranças, Dashboard Global, Planos e Assinaturas Globais) com controle de privilégio do superadmin. Corrigido erro Uncaught TypeError/filter em listas sem dados recebidos.
- Tests: Pass

### Ship-feature-financial-nfe-integration-2026-07-10
- Feature shipped: Homologação e ativação dos testes E2E do gateway Asaas na VPS. Registrado o webhook de ingress com token dinâmico `whsec_...` e garantido sincronismo de submodules locais com a VPS.
- Tests: Pass

### Ship-main-2026-07-10-asaas-nfe-integration
- Feature shipped: Integração de Notas Fiscais Municipais (NF-e) via Asaas (Fase 4), emissão assíncrona com retentativas no Sidekiq, endpoints de relatório fiscal superadmin e download direto no frontend. Configurado o deploy de produção no vps-docker-compose.yml.
- Tests: Pass

### Ship-main-2026-07-10-webhook-signature-verification
- Feature shipped: Strict Webhook Signature Verification at HTTP boundary using SVIX (Gap 4). Rejects forged events with 401 Unauthorized directly at WebhooksController.
- Tests: Pass

### Ship-feature-financial-frontend-ui-2026-07-10
- Feature shipped: Estabilização do Frontend do Módulo Financeiro (Fase 3), corrigindo imports não utilizados do React (TS6133) que impediam a compilação do bundle de produção do Vite.
- Tests: Pass

### Ship-feature-asaas-dunning-sidekiq-2026-07-10
- Feature shipped: Resiliência de Cobrança e Dunning via Sidekiq (Fase 4), enforcando a suspensão automática de contas com período de graça expirado e chamadas seguras S2S para evo-auth.
- Tests: Pass

### Ship-feature-asaas-billing-webhooks-2026-07-10
- Feature shipped: Homologação e Testes E2E de Webhook (Fase 3), incluindo criação de fixture JSON, validação de token e segurança de idempotência.
- Tests: Pass

### Ship-feature-asaas-real-integration-2026-07-10
- Feature shipped: Sincronização de Clientes Asaas com validação local de documentos (CPF/CNPJ com dígitos exatos de 11 e 14) e mapeamento de erros 400 da API externa para 422 locally.
- Tests: Pass

### Ship-main-2026-07-10-financial-management-phase-2
- Feature shipped: Fase 2 (Integração Asaas, Webhooks, Enforcamento/Grace Period e Suspensão evo-auth) do evo-billing-service. Inclui cliente Asaas, webhook seguro HMAC/idempotente, Sidekiq dunning job e endpoints internos S2S.
- Tests: Pass

### Ship-main-2026-07-09-financial-management-phase-1
- Feature shipped: Fase 1 (Infraestrutura + Schema + CRUD de Planos e Assinaturas) do evo-billing-service, incluindo isolamento de tenant, autenticação JWT baseada em chaves públicas e RSpec completo (18 specs) verde.
- Tests: Pass

### Ship-main-2026-07-10-onboarding-vertical-guides
- Feature shipped: Criados `ONBOARDING-CLINICA.md` (17.1 KB) e `ONBOARDING-ECOMMERCE.md` (16.3 KB) em `F:\Evolution-CRM\Roadmap\` — guias verticais com 10 seções cada, 8 templates copy-paste, 3 jornadas, 2 pipelines, campanhas e troubleshooting específico para clínicas/estútios e e-commerce/varejo.
- Tests: Pass

- **2026-07-07**: Deploy do serviço evo-flow (NestJS) na VPS, correção do Nginx gateway (upstream flow_service para jornadas/campanhas), resolução dos conflitos de porta do Traefik, e criação da documentação de Single Source of Truth (MULTI_TENANT_MAP.md, DESCOBERTAS_CONSOLIDADAS.md, DEPLOYMENT_GUIDE.md).
- **2026-07-07**: Correção de TLS (certificado SSL expandido para api.bodyharmony.tech) e correção do healthcheck do container evo-auth (shebang CRLF convertido para LF). Tenant Body Harmony configurado e credenciais de superadmin e suporte provisionadas.
- **2026-07-06**: Entrega MVP (5 rodadas). `auth-api` configurado and `evolution-go` (crm-api) licensed. Ambiente legado removido. Infraestrutura rodando no Traefik (porta 4000, 3001). Cliente Body Harmony provisionado com superadmin.
