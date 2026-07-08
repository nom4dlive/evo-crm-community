# Governance Audit Report — System Governance (2026-07-08)

**Baseline:** validate FAIL · 1 known findings excluded
**Findings:** 9 verified (3 do-now · 5 backlog · 1 closed) · 0 false alarms dropped

---

## 1. Already-Known List
- **ADR Frontmatter Warning** (GOV-001 / docs/adr/ADR-001-tenant-routing.md): Known warning about missing frontmatter headers in ADR files, tracking in `docs/specs/_product-backlog.md` under Row 1.

---

## 2. Verified Findings

### Finding 1: AGENTS.md missing routing index reference [do-now]
- **Observation:** Running `validate.ps1` or `validate.sh` fails with `[FAIL] AGENTS.md missing routing index reference (authority handoff absent)`.
- **Verification:** Inspection of `AGENTS.md` confirms that the file does not reference `.agent/workflows/routing.md`.
- **Disposition:** `do-now` (Will be resolved in a follow-up task by referencing the routing index in `AGENTS.md`).

### Finding 2: Safety nucleus freshness [do-now]
- **Observation:** Running `generate_safety_nucleus.py --check` fails with `ERROR: ACX:SAFETY-FLOOR BEGIN/END markers not found (or malformed) in AGENTS.md`.
- **Verification:** Inspection of `AGENTS.md` confirms it lacks the `<!-- ACX:SAFETY-FLOOR:BEGIN -->` and `<!-- ACX:SAFETY-FLOOR:END -->` comment fences.
- **Disposition:** `do-now` (Will add the fences around the Core Directives safety section in `AGENTS.md` in a follow-up task).

### Finding 3: Spec file missing status field [do-now]
- **Observation:** Validator warning: `docs/specs/ files missing YAML frontmatter or status field: 1`.
- **Verification:** Inspected `docs/specs/tenant-isolation-auth.md` and confirmed it lacks the required YAML frontmatter status header.
- **Disposition:** `do-now` (Will add frontmatter with `status: draft` in a follow-up task).

### Finding 4: Legacy rule surfaces and Codex rules file missing [backlog]
- **Observation:** Validator fails with `[FAIL] legacy rule surfaces present` and `[FAIL] codex rules file missing: .../.codex/rules/default.rules`.
- **Verification:** Confirmed that the `.codex/` directory is completely missing from the root of the repository.
- **Disposition:** `backlog` (Tracked in `_product-backlog.md` under Row 8 to restore the missing files).

### Finding 5: Old reviews routing_actions contract violations [backlog]
- **Observation:** Validator fails with `[FAIL] routing_actions contract violations detected` due to older reviews pointing to non-existent files or invalid target formats.
- **Verification:** Inspected `2026-07-06-govern-audit.md`, `2026-07-07-audit.md`, and `2026-07-08-audit.md` and verified their `routing_actions` blocks target invalid paths.
- **Disposition:** `backlog` (Tracked in `_product-backlog.md` under Row 4 to repair the old reviews' blocks).

### Finding 6: Security scanning workflow absent [backlog]
- **Observation:** Validator warning: `[WARN] security scanning workflow absent — .github/workflows/security.yml not found`.
- **Verification:** Confirmed that `.github/workflows/security.yml` does not exist.
- **Disposition:** `backlog` (Tracked in `_product-backlog.md` under Row 6).

### Finding 7: Token lifecycle baseline absent [backlog]
- **Observation:** Validator warning: `[WARN] token lifecycle baseline absent (.agentcortex/metadata/lifecycle-baseline.json)`.
- **Verification:** Confirmed the file does not exist.
- **Disposition:** `backlog` (Tracked in `_product-backlog.md` under Row 7).

### Finding 8: Archived work logs metadata and broken relative links [backlog]
- **Observation:** Validator warnings about missing Current Phase, Checkpoint SHA, and broken relative links in archived work logs.
- **Verification:** Verified several archive files have broken links and missing headers.
- **Disposition:** `backlog` (Tracked in `_product-backlog.md` under Row 10).

### Finding 9: Local validator CI-only skips [closed-with-reason]
- **Observation:** Deep metadata and provenance checks are skipped during local validator runs.
- **Verification:** Output lists: `[SKIP] metadata deep checks`, `[SKIP] compact index freshness`, `[SKIP] skill provenance`, `[SKIP] audit chain integrity`.
- **Disposition:** `closed-with-reason` (Working as intended. Bypassed safely in local environments).

---

## 3. Dropped False Alarms
None.

---

## 4. Routing Actions

```yaml
routing_actions:
  - finding: "Reference routing index in AGENTS.md and add safety floor markers"
    target_doc: "docs/specs/stabilization.md"
    status: pending
    owner: "unassigned"
  - finding: "Fix tenant-isolation-auth.md missing frontmatter status field"
    target_doc: "docs/specs/tenant-isolation-auth.md"
    status: pending
    owner: "unassigned"
  - finding: "Establish security scanning workflow and token lifecycle baseline"
    target_doc: "docs/specs/stabilization.md"
    status: pending
    owner: "unassigned"
  - finding: "Restore missing .codex directory and repair old review routing actions"
    target_doc: "docs/specs/stabilization.md"
    status: pending
    owner: "unassigned"
```
