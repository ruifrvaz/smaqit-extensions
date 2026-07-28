---
name: smaqit.parity-assess
description: Produces a structured parity assessment comparing any two software systems — frameworks, libraries, platforms, or products. Identifies the current project from session context, studies the target system, checks domain compatibility, then outputs validated Mermaid diagrams and a written ASSESSMENT.md. Trigger phrase: `parity.assess <name>`.
metadata:
  version: "2.0.0"
---

# Parity Assess

## Steps

### Phase 0 — Identify the Current Project (Project A)

Use session context first. If not available, read the project README and primary config/instructions file.

Record:
- **Domain** — the problem the project solves (2–3 words, e.g., "voice AI agent", "CI pipeline tool", "web framework")
- **Core abstractions** — the 3–5 central types or concepts the system is built around
- **Processing model** — how the system handles a primary operation (request → response, event → action, input → output)
- **Technology** — language, runtime, key frameworks
- **Key capabilities** — the top 5–7 features that define what the system does

---

### Phase 1 — Identify the Target System (Project B)

Use `mcp_github_mcp_se_get_file_contents` for GitHub sources; use `fetch_webpage` for non-GitHub sources.

Fetch in priority order — stop when the five targets below are known:

1. Root `README.md`
2. Root `AGENTS.md`, `CONTRIBUTING.md`, or equivalent overview doc
3. Package-level `README.md` files (monorepos: iterate top-level packages)
4. `docs/` directory listing → read architecture/design/overview docs (skip missing)
5. Source directory listing for core packages → read the top 1–3 most architecturally significant files (≤20 KB each)

> **Note:** `mcp_github_mcp_se_get_file_contents` may write large results to a file path. Read that path before using the content.

Record the same five targets as Phase 0:
- **Domain** — the problem Project B solves
- **Core abstractions** — Project B's 3–5 central types or concepts
- **Processing model** — how Project B handles its primary operation
- **Technology** — language, runtime, key frameworks
- **Key capabilities** — the top 5–7 features

---

### Phase 2 — Domain Compatibility Gate

Compare the **Domain** of Project A and Project B.

**Compatible domains** — proceed to Phase 3:
- Same domain (e.g., both are agent orchestrators)
- Adjacent domains with meaningful overlap (e.g., agent framework vs pipeline orchestrator)
- One is a potential dependency or integration target for the other

**Incompatible domains — full stop:**
- Completely different problem spaces with no overlap (e.g., web application vs columnar database)
- No plausible integration, adoption, or feature-parity path

If incompatible: report to the user why the comparison is not meaningful and stop. Do not produce diagrams or an assessment.

---

### Phase 3 — Generate Diagrams

Read `references/DIAGRAM_GUIDE.md` **before writing any Mermaid code**.

Discover the output root: check if `docs/parity/` or `docs/orchestrator/parity/` exists and use the one that does; default to `docs/parity/` if neither exists.

Set `OUTPUT_DIR = <parity-root>/<name>/`. If it already exists, confirm with the user before overwriting.

Create the output directory by writing the first file into it. Produce up to four diagram files — skip any that are not applicable to the systems being compared:

| # | Filename | Diagram type | Content |
|---|----------|-------------|---------|
| 1 | `01-<name>-architecture.md` | `flowchart TD` | Project B's component/package structure and data flow |
| 2 | `02-<name>-core-flow.md` | `sequenceDiagram` | Project B's primary processing cycle (request, event, turn — whatever applies) |
| 3 | `03-<name>-state-model.md` | `flowchart TD` | Project B's state/data persistence model (omit if stateless or N/A) |
| 4 | `04-<name>-vs-<project-a>-feature-gap.md` | `flowchart LR` | Side-by-side feature comparison, colour-coded by parity status |

**After writing each diagram file, run `mermaid-diagram-validator`. Do not proceed until the current diagram validates.**

---

### Phase 4 — Write Assessment

Read `references/ASSESSMENT_TEMPLATE.md` before writing.

Write `<OUTPUT_DIR>/ASSESSMENT.md` with all five mandatory sections:

1. **What `<name>` is** — factual description, purpose, language/runtime, key differentiators
2. **Structural mapping** — table pairing each Project B concept with Project A's equivalent
3. **Relationship options** — concrete options for how the two systems could relate (adopt, integrate, reference, replace, ignore)
4. **Recommendation** — one clear choice with numbered rationale
5. **Parity roadmap** — ordered table of features/gaps worth closing

---

### Phase 5 — Register

Look for a parity index file (e.g., `<parity-root>/README.md`). If it exists, add a row for the new assessment. If it does not exist, skip this step.

---

### Phase 6 — Report

Return to user:
- Paths of all files created
- One-sentence recommendation from the assessment
- Any items marked `[?]` in outputs

---

## Completion Criteria

- [ ] Project A domain and capabilities recorded from session context or workspace
- [ ] Project B domain and capabilities recorded from source
- [ ] Domain compatibility confirmed before proceeding
- [ ] All applicable diagram files created and validated
- [ ] `ASSESSMENT.md` present with all five mandatory sections
- [ ] Parity index updated (if it exists)
- [ ] No `[?]` items left unacknowledged in the report

---

## Failure Handling

| Situation | Action |
|-----------|--------|
| No URL provided | Ask for it before Phase 1 |
| Source not on GitHub | Use `fetch_webpage`; mark gaps with `[?]` |
| Source private / inaccessible | Proceed with public docs; mark unknowns `[?]` |
| Domains are incompatible | Report and stop — do not produce output |
| Output directory already exists | Confirm with user before overwriting |
| Mermaid validation fails | Fix in memory; re-validate before writing to disk |
| System has no state model | Omit diagram 3; note it in the assessment |
| Large file response written to path | Read that path before using content |

---

## References

Read when the condition is met:

- `references/DIAGRAM_GUIDE.md` — **always**, at the start of Phase 3
- `references/ASSESSMENT_TEMPLATE.md` — **always**, at the start of Phase 4
