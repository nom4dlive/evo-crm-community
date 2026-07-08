---
title: Product Backlog — Evolution CRM Community
created: 2026-07-08
status: living
---

# Product Backlog — Evolution CRM Community

This file tracks the active product and governance backlog items as part of the Multi-Tenant vNext roadmap.

## Feature Inventory

| # | Feature | Kind | Labels | Priority | Status | Tier | Spec File | Dependencies |
|---|---|---|---|---|---|---|---|---|
| 1 | Add missing YAML frontmatter headers to ADR files | refactor | docs/adr | Low | Shipped | Core | docs/adr/ADR-001-tenant-routing.md | None |
| 2 | Establish product backlog file `docs/specs/_product-backlog.md` | feature | docs/specs | Low | Shipped | Core | docs/specs/_product-backlog.md | None |
| 3 | Reference routing index `.agent/workflows/routing.md` in `AGENTS.md` | refactor | docs/governance | Low | Shipped | Core | AGENTS.md | None |
| 4 | Resolve routing_actions target_doc contract violations in old reviews | bugfix | docs/reviews | Low | Pending | Core | docs/reviews/2026-07-08-govern-audit.md | None |
| 5 | Add YAML frontmatter status field to `docs/specs/tenant-isolation-auth.md` | refactor | docs/specs | Low | Shipped | Core | docs/specs/tenant-isolation-auth.md | None |
| 6 | Add security scanning workflow `.github/workflows/security.yml` | feature | ci/security | Medium | Pending | Core | None | None |
| 7 | Seed token lifecycle baseline `.agentcortex/metadata/lifecycle-baseline.json` | feature | docs/governance | Low | Pending | Core | None | None |
| 8 | Restore missing `.codex` directory and rule files | bugfix | docs/governance | Medium | Pending | Core | None | None |
| 9 | Add `ACX:SAFETY-FLOOR` BEGIN/END markers to `AGENTS.md` | bugfix | docs/governance | Medium | Shipped | Core | AGENTS.md | None |
| 10 | Repair historical work logs metadata and broken relative links in archive | bugfix | docs/governance | Low | Pending | Core | None | None |
