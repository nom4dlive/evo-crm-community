# AGENTS.md — Evolution CRM Multi-Tenant

## Chat Language Policy

Reply in the user's input language (detect from latest message). Code, commits, specs, ADRs, rules stay in English.

## Core Directives

- **MUST OBEY**: `.agent/rules/engineering_guardrails.md`
- **MUST OBEY**: `.agent/rules/security_guardrails.md`
- Correctness first. MUST NOT claim completion without verifiable evidence.
- Small, reversible changes. Unauthorized refactoring strictly prohibited.
- **Destructive Command Gate** (deny-by-default): before `rm -rf`, `git reset --hard`, force pushes, etc., state blast radius + rollback plan, get confirmation.
- **Secrets Prohibition**: NEVER write, commit, echo, or log credentials/API keys/tokens.
- **No Bypass Rule**: MUST NOT skip Gate/Evidence checks.

## graphify — Knowledge Graph Integration

This project has a knowledge graph at `graphify-out/` with god nodes, community structure, and cross-file relationships (**62.276 nós, 109.313 edges, 5.294 comunidades**).

Full command reference: `graphify-out/GRAPHIFY_COMMANDS.md`

### WORKFLOW INTEGRATION (do this before, during, and after every change)

**1. Research (before coding)**
- `graphify query "<question>"` — understand architecture, flows, relationships (scoped subgraph, much smaller than grep)
- `graphify path "<A>" "<B>"` — shortest path between two nodes
- `graphify explain "<concept>"` — plain-language explanation of a node and its neighbors
- `graphify affected "<file>"` — reverse traversal to find what depends on X

**2. Validation (before refactor)**
- `graphify affected "arquivo-que-vou-mudar"` — identify what will break
- `graphify path "serviço-A" "serviço-B"` — confirm integration contracts

**3. Sync (after coding)**
- `graphify update .` — re-extract code files and update graph (AST-only, no API cost)
- `graphify update --force .` — overwrite even if graph shrinks (use after deleting files)
- If DB schema changed: `python extract_schemas.py .`

**4. Commit hooks**
- Post-commit: auto `graphify update .` keeps graph fresh

### RULES

1. **SEMPRE** use `graphify query` before `grep` — returns scoped subgraph, usually much smaller than raw output
2. **NUNCA** skip graphify because `graphify-out/` is dirty — expected after hooks/incremental updates
3. **SEMPRE** run `graphify update .` after modifying code
4. **CONSULTE** `graphify-out/GRAPH_REPORT.md` only for broad architecture review
5. **CONSULTE** `graphify-out/MULTI_TENANT_MAP.md` — multi-tenant context (estado atual, delta por fase, testes)
6. **CONSULTE** `graphify-out/DESCOBERTAS_CONSOLIDADAS.md` — known gaps (45 lacunas: 6🔴 12🟡 20🟢 7🔵)
7. **CONSULTE** `graphify-out/DEPLOYMENT_GUIDE.md` for operations
8. **USAR** `graphify affected "<file>"` BEFORE refactors

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `graphify update` says graph has more nodes | Use `--force` |
| graphify-out/ is dirty | Ignore — expected after hooks or incremental updates |
| Graph missing new files | Run `graphify update .` |
| Custom extractors stale | `python extract_schemas.py .` |

## Agentic OS Workflow Integration

This project uses **Agentic OS** for gated development workflows.

### Commands

| Command | When to use |
|---------|-------------|
| `/bootstrap` | Start a new task — loads context, classifies, outputs plan |
| `/plan` | Create implementation plan with spec |
| `/implement` | Execute planned changes |
| `/review` | Review changes for correctness, security, governance |
| `/test` | Run and verify tests |
| `/ship` | Final gate — checks evidence, updates SSoT |
| `/handoff` | Pass work to another session/agent |
| `/audit` | Read-only assessment of current state |
| `/spec-intake` | Decompose multi-feature input into feature inventory |
| `/adr` | Create Architecture Decision Record |

### Classification System

| Classification | Required phases |
|:---|:---|
| **tiny-fix** | Classify → Execute → Evidence → Done |
| **quick-win** | Bootstrap → Plan → Implement → Evidence → Ship |
| **feature** | Bootstrap → Spec → Plan → Implement → Review → Test → Handoff → Ship |
| **hotfix** | Bootstrap → Research → Plan → Implement → Review → Test → Ship |
| **architecture-change** | Bootstrap → ADR → Spec → Plan → Implement → Review → Test → Handoff → Ship |

### Delivery Gates

- NO EVIDENCE = NO COMPLETION
- `/review` phase MUST end with Verdict: PASS to satisfy the review gate
- Ship checks: scope → quality → evidence → risk → communication

## vNext State Model

- **Init Read**: Read `.agentcortex/context/current_state.md` (SSoT) + `.agentcortex/context/work/<worklog-key>.md`
- **Write Isolation**: Agents write only to their own Work Log. Only `/ship` updates SSoT.
- **Classification Freeze**: Locked after bootstrap. Silent downgrade prohibited.

## Context-Bound Confirmation

If conversation context changes (branch switch, new session), re-confirm intent before proceeding. Work Log must contain `Owner` + `Branch`.

## References

- Workflows: `.agent/workflows/*.md`
- Rules: `.agent/rules/engineering_guardrails.md`, `.agent/rules/security_guardrails.md`
- Graphify commands: `graphify-out/GRAPHIFY_COMMANDS.md`
- Multi-tenant map: `graphify-out/MULTI_TENANT_MAP.md`
- Known gaps: `graphify-out/DESCOBERTAS_CONSOLIDADAS.md`
- Deploy guide: `graphify-out/DEPLOYMENT_GUIDE.md`
