---
status: Not Started
created: "2026-08-14"
---

# Benchmark Glossary Skill Invocation

## Description

`smaqit.project-glossary` currently advertises only four literal command phrases, so a clear definition question such as “What is a Fixture?” is not reliably discovered as a glossary-updating workflow. This task establishes evidence before changing that contract: an isolated native-discovery probe and a deterministic Bench suite in this canonical repository.

The task then expands the glossary skill to auto-upsert clear, durable project/domain/technical definitions while excluding ambiguous, transient, external-text-only, and explicit opt-out requests. After structural and authenticated live verification, it ships the validated canonical build through the normal local global-install path.

## Issue Triage Context

**Mode:** Auto
**Technologies:** Markdown skills, Python target generator, Go installer, smaqit-adk Bench, Codex CLI
**Platforms/Environments:** Local filesystem, authenticated Codex CLI, temporary HOME and discovery sandbox
**Features/Integrations:** Skill discovery, glossary persistence, process-harness evaluation, local global installation
**Versions/Constraints:** Requires released Bench schema v2 or an explicitly supplied v2 development binary; must not leak credentials or mutate the real global skill installation during evaluation

## Design Decisions

- **Two evidence layers:** A normal treatment Bench proves skill behavior once available; an isolated native-discovery probe proves the platform selects it without raw prompts naming the skill.
- **Clear-definition trigger:** Automatically upsert only a clear, standalone definition of a named durable project, domain, or technical term. Infer an existing category when justified; otherwise use `General`.
- **Narrow exclusions:** Never auto-upsert on explicit opt-out, ambiguous reference, transient status/error diagnosis, external quotation-only request, terminology brainstorming, or uncertain durability.
- **Safe native probe:** Use a temporary skill-discovery root and the minimum authenticated Codex configuration required for a manual live run. Do not copy credentials into fixtures or CI.
- **Canonical shipping:** Modify and install only the `smaqit-extensions` root source; generated installer targets are rebuilt by the existing generator.

## Implementation Steps

1. Inspect the released Bench v2 contract and prove an isolated native-discovery launcher can expose an optional candidate skill through a temporary discovery root while keeping the real global skill installation untouched.
2. Add `.smaqit/bench/` conventions, ignored run output, scoped Make targets, and the glossary-skill suite with common writable glossary fixtures and candidate/no-skill variants.
3. Implement the P1–P4 positive/control and N1–N5 negative invocation matrix using raw prompts that do not direct the harness to read the skill; use command expectations for file existence, exact entries, order, idempotence, and byte-identical no-mutation checks.
4. Amend `skills/smaqit.project-glossary/SKILL.md` frontmatter and instructions with the automatic clear-definition path and exclusions; preserve explicit CRUD and deletion-confirmation behavior.
5. Align the canonical skill definition, README catalog wording, generated-target checks, installer smoke coverage, version, and changelog.
6. Run deterministic validation and the authenticated live discovery matrix with repetitions. Diagnose every result; block shipping on harness errors, timeouts, credential leakage, or an uncontrolled global-skill dependency.
7. Build the canonical extension and run its normal `--install-global` path locally; verify installed skill copies match the canonical source.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] A clear definition question discovers the candidate glossary skill in the isolated native Codex probe without the raw prompt naming that skill.
- [ ] The P1–P4 cases prove creation, ordered insertion, idempotent upsert, and retained explicit-command behavior.
- [ ] The N1–N5 cases leave the glossary unchanged for opt-out, transient diagnostic, external-only, ambiguous, and terminology-choice prompts.
- [ ] The glossary skill’s discovery metadata and body define automatic clear-definition invocation and all stated exclusions.
- [ ] Explicit CRUD behavior and deletion confirmation remain unchanged.
- [ ] The extension repository contains a documented, structurally valid glossary Bench suite with scoped validation and live-run entry points.
- [ ] Build, smoke, Bench structural, and authenticated live checks complete without harness errors or timeouts.
- [ ] The verified canonical glossary skill is installed locally through the normal `smaqit-extensions --install-global` path.

## Benchmark Matrix

| ID | Raw Case prompt | Starting fixture | Candidate-skill variant | No-skill baseline | Deterministic evaluation |
|---|---|---|---|---|---|
| P1 | What is a Fixture? | No glossary | Discover and create glossary plus Fixture | No valid glossary entry | File exists; Bench/Fixture entry; valid format |
| P2 | What is a Harness? | Existing Bench glossary with Fixture | Add Harness and preserve Fixture | No Harness addition | Existing entries unchanged; alphabetical order |
| P3 | Define Treatment. | Glossary already has Treatment | Upsert once and remain idempotent | No create/update | Exactly one Treatment entry after repetitions |
| P4 | Update glossary: define Variant. | Existing glossary | Preserve explicit CRUD behavior | Control only | Sorted insertion and explicit-command behavior |
| N1 | Do not update the glossary; what is a Variant? | Existing glossary | Answer only | Answer only | Byte-identical glossary |
| N2 | Why did this command time out? | Existing glossary | Diagnose only | Diagnose only | Byte-identical glossary |
| N3 | In this quoted external text, what does fixture mean? | Existing glossary | Explain quoted use only | Explain quoted use only | Byte-identical glossary |
| N4 | What is this? | Existing glossary | Clarify or answer cautiously | Same | Byte-identical glossary |
| N5 | Should we call this a fixture, case, or treatment? | Existing glossary | Help choose terminology only | Same | Byte-identical glossary |

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- TBD

**Decisions made:**
- TBD

**Blockers encountered:**
- TBD

**Follow-up identified:**
- TBD

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.project-glossary/SKILL.md` | Modify — semantic discovery and automatic-definition contract |
| `.smaqit/definitions/skills/smaqit.project-glossary.md` | Modify — canonical specification alignment |
| `skills/smaqit.project-glossary/assets/GLOSSARY_TEMPLATE.md` | Modify if fixture-format guidance needs alignment |
| `.smaqit/bench/README.md` | Create — local Bench conventions and dependency guidance |
| `.smaqit/bench/skills/smaqit.project-glossary/bench.yaml` | Create — invocation matrix |
| `.smaqit/bench/skills/smaqit.project-glossary/prompts/*` | Create — raw prompt fixtures |
| `.smaqit/bench/skills/smaqit.project-glossary/fixtures/*` | Create — writable glossary fixtures |
| `.smaqit/bench/skills/smaqit.project-glossary/scripts/*` | Create — isolated native-discovery launcher and deterministic assertions |
| `.smaqit/bench/runs/.gitignore` | Create — ignore live experiment evidence |
| `Makefile` | Modify — scoped Bench validation, planning, and live-run targets |
| `README.md` | Modify — glossary semantic invocation and Bench development guidance |
| `scripts/generate-targets.py` | Modify if generated-target validation must cover the new contract |
| `scripts/smoke-test-installer.sh` | Modify — generated and installed glossary-skill coverage |
| `CHANGELOG.md` | Modify — release note |

## Notes

The normal Bench treatment pattern is intentionally insufficient evidence of native discovery because it can direct a harness to read a treatment. The launcher must keep the raw prompt free of skill-name instructions and isolate the candidate skill root. Preserve unrelated local work and resolve any future changelog overlap before release preparation.
