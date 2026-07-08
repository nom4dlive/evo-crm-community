# Governance Audit Report (2026-07-08)

**Baseline:** validate warn · 0 known findings excluded
**Findings:** 4 verified (1 do-now · 1 backlog · 2 closed) · 0 false alarms dropped

---

## 1. Already-Known List
No prior governance findings were active in `_product-backlog.md` (file was missing).

---

## 2. Verified Findings

### Finding 1: ADR Frontmatter Warning [do-now]
- **Observation:** Running `validate.ps1` outputs two warning messages indicating that the ADR files are missing frontmatter:
  - `[WARN] docs/adr/ADR-001-tenant-routing.md — downstream user content (advisory): frontmatter missing or unparseable`
  - `[WARN] docs/adr/ADR-002-tenant-isolation-auth.md — downstream user content (advisory): frontmatter missing or unparseable`
- **Verification:** Inspection of both `docs/adr/ADR-001-tenant-routing.md` and `docs/adr/ADR-002-tenant-isolation-auth.md` confirmed that no frontmatter headers are defined at the start of these files.
- **Disposition:** `do-now` (Will be resolved in a follow-up task by adding the required YAML frontmatter header block to both ADR files).

### Finding 2: Missing Product Backlog File [backlog]
- **Observation:** The governance system expects a backlog tracking file at `docs/specs/_product-backlog.md`, but the file is missing from the directory.
- **Verification:** A workspace search for `_product-backlog.md` returned no results.
- **Disposition:** `backlog` (Will create `docs/specs/_product-backlog.md` in this audit run as a permitted write to establish the backlog database).

### Finding 3: CI-only Validator Checks Skipped [closed-with-reason]
- **Observation:** The local validator skips several metadata, provenance, and deep check steps.
- **Verification:** Observed output:
  - `[SKIP] metadata deep checks -- CI-only validator not deployed`
  - `[SKIP] compact index freshness -- CI-only generator not deployed`
  - `[SKIP] skill provenance + compatibility floor -- tool not present`
  - `[SKIP] audit chain integrity (INDEX.jsonl) -- tool not present`
- **Disposition:** `closed-with-reason` (Working as intended. These checks are designed exclusively for CI server execution environments and are safely bypassed during local manual execution).

### Finding 4: Parity Between validate.sh and validate.ps1 [closed-with-reason]
- **Observation:** Checked for potential check-parity drift between Windows and Linux validator entrypoints.
- **Verification:** Inspected both scripts and verified they cover the same list of files, directories, and sync/provenance logic.
- **Disposition:** `closed-with-reason` (Working as intended. The scripts are functionally synchronized).

---

## 3. Dropped False Alarms
None.

---

## 5. Routing Actions

```yaml
routing_actions:
  - finding: "Missing frontmatter headers in docs/adr/ADR-001-tenant-routing.md and docs/adr/ADR-002-tenant-isolation-auth.md"
    target_doc: "docs/adr/ADR-001-tenant-routing.md"
    status: pending
    owner: "unassigned"
  - finding: "Establish docs/specs/_product-backlog.md tracking file for backlog intake"
    target_doc: "docs/specs/tenant-isolation-auth.md"
    status: pending
    owner: "unassigned"
```
