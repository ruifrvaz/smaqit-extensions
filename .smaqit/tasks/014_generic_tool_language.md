---
status: Completed
mode: Assisted
created: "2026-07-16"
completed: "2026-07-16"
---

# Generic Tool Language for Memory, Transcript, and Question-Asking Steps

## Description

Follow-up to tasks 012/013. A closer re-examination (prompted by the user spotting `smaqit.session-finish`'s hardcoded `` `memory` `` tool reference) found that several skills hardcode specific tool names that only exist on one platform — and in one case, three *different* inconsistent tool names for the same concept, none of which are real Claude Code tools. Unlike tasks 012/013 (which needed genuine per-platform content branching for irreconcilable mechanisms), these cases just need **generic, capability-conditional language** — "if available, use it; otherwise fall back" — requiring no generator involvement and no platform branching at all, since the same wording is correct on both platforms.

Four categories of finding, all confirmed by direct grep across all 28 skills:

1. **Memory persistence — three inconsistent tool names, none real on Claude Code:**
   - `` `memory` `` tool with `type: workspace` (subject/fact/citations/reason schema) — `smaqit.session-finish`, `smaqit.session-start`
   - `` `store_memory` `` tool (same schema, different name) — `smaqit.task-create`, `smaqit.task-start`, `smaqit.task-complete`
   - bare `` `memory` `` tool with a `/memories/session/plan.md` path convention — `smaqit.task-plan`
   
   None of these are real Claude Code tools (verified: no `memory`/`store_memory` tool exists in a live Claude Code tool list). Copilot's own real tool ID is `vscode/memory` (per this repo's agent frontmatter) — a *fourth* name — confirming these three conventions arose from mixed provenance, not one deliberate design.

2. **`{{VSCODE_TARGET_SESSION_LOG}}`** — a VS Code Copilot runtime variable (not resolved by our build-time generator) used to derive a transcript `.jsonl` path in `smaqit.session-finish`, `smaqit.session-recap`, `smaqit.session-title`. This is a semantic gap, not just a naming one: Claude Code doesn't need a transcript file at all — the full conversation is already natively in context.

3. **`vscode_askQuestions`** — literal VS Code tool ID, hardcoded twice in `smaqit.task-plan`.

4. **A real bug, not just cosmetic:** `smaqit.utils.read-pdf`'s frontmatter already has a Claude-style `allowed-tools:` field, but with wrong tool names (`run_in_terminal read_file` instead of Claude's actual `Bash`/`Read`) — as shipped, this would restrict the skill from using `Read` at all under Claude Code. The same file separately references a nonexistent skill directory (`smaqit.read-pdf` instead of `smaqit.utils.read-pdf`) in its own example command, and skips the `[SMAQIT_SKILLS_DIR]` placeholder entirely.

Lower-severity: informal `` `read_file` `` mentions (not a declared restriction, just prose) in `smaqit.session-recap`, `smaqit.session-title`, `smaqit.test-complete`, `smaqit.parity-assess` (×2) — normalize for consistency while touching these files, low risk either way.

## Design Decisions (confirmed)

- **No generator/placeholder mechanism needed for this task.** Unlike `smaqit.project-init`/`smaqit.release-git-pr` (task 013), which had genuinely different content per platform, these skills just need wording that's *correct on both platforms simultaneously* — "if a capability is available, use it; otherwise skip / fall back to X." Same text ships to `.github/skills/` and `.claude/skills/` unchanged.
- **File-based storage remains the mandatory, authoritative record; a named memory tool (if any) is an optional accelerant.** This repo already has robust file-based mechanisms for everything memory touches: `.smaqit/history/`, `.smaqit/tasks/PLANNING.md` + task files, `.smaqit/glossary.md`, `.smaqit/compendium.md`. Cross-branch continuity is the one real capability a memory tool adds beyond what files alone provide (files on another branch aren't visible until merged) — so the memory step becomes best-effort/conditional, not a hard requirement, and nothing regresses when it's unavailable.
- **Preserve the subject/fact/citations/reason schema as descriptive guidance**, not as a literal tool-call signature — it's a reasonable, tool-agnostic shape for a memory entry regardless of what (if anything) ultimately stores it.
- **Session-transcript reading becomes conditional, not deleted.** `smaqit.session-finish`/`recap`/`title`'s Step 0 gets a first branch — "if the full conversation is already in your context, use it directly" — with the existing `{{VSCODE_TARGET_SESSION_LOG}}`-based log-reading kept as a fallback branch for environments that need it (unchanged Copilot behavior).
- **`vscode_askQuestions` → plain description of the action** ("ask the user clarifying questions, one logical cluster per interaction..."), no tool name at all.
- **`smaqit.utils.read-pdf`'s `allowed-tools:` gets corrected values** (`Bash Read`) — this field is Claude Code-only syntax (confirmed: no other skill in this repo uses it, and Copilot has no equivalent skill-frontmatter field), so correcting the value is a straightforward fix with no platform branching needed; Copilot silently ignores a frontmatter field it doesn't use, same as it already does today.

## Implementation Steps

1. **`skills/smaqit.session-finish/SKILL.md`**:
   - Step 0: add a first branch — if the full conversation is already available in context, use it directly as the session arc source; keep the existing `{{VSCODE_TARGET_SESSION_LOG}}`-based transcript-read/summarize-script logic as the fallback branch for environments that need it.
   - Step 2: reword "Store session context in memory using the `memory` tool with `type: workspace`" → "If a persistent, cross-session memory/notes capability is available in this environment, use it to record the following (best-effort — the history file above remains the source of truth either way)". Keep the subject/fact/citations/reason bullets as descriptive guidance.
   - Requirements: reword "Always call the `memory` tool with `type: workspace`..." to match (conditional, not mandatory).
2. **`skills/smaqit.session-start/SKILL.md`**:
   - Step 2: reword "Use the `memory` tool with `type: workspace` to retrieve..." → "If a persistent memory/notes capability is available, check it for stored entries with subjects...". Keep file-based fallback (already present) as the primary path when unavailable.
   - Step 3: same treatment for the task-state entry.
3. **`skills/smaqit.session-recap/SKILL.md`** and **`skills/smaqit.session-title/SKILL.md`**: same Step 0 conditional rework as session-finish (both currently have near-identical Step 0 blocks). Normalize the informal `` `read_file` `` mention to generic phrasing.
4. **`skills/smaqit.task-create/SKILL.md`**, **`skills/smaqit.task-start/SKILL.md`**, **`skills/smaqit.task-complete/SKILL.md`**: reword each "Store task state in memory using the `store_memory` tool" step to the same conditional/generic pattern as session-finish's Step 2, preserving the subject/fact/citations/reason guidance.
5. **`skills/smaqit.task-plan/SKILL.md`**: rework all `/memories/session/plan.md` references (Steps 12/13/14, Mode B option 3 in step 15, Output section, both Gotchas mentions, Failure Handling row) to: "if a session-scoped memory/scratch-storage capability is available, save the plan there as a durability backup (create or overwrite) — optional; the plan is always shown in full in chat (Step 13), which remains authoritative regardless." Replace both `vscode_askQuestions` mentions (Phase 3 step 9, Phase 5 step 14) with plain action description, no tool name.
6. **`skills/smaqit.utils.read-pdf/SKILL.md`**: fix `allowed-tools: Bash run_in_terminal read_file` → `allowed-tools: Bash Read`; fix the example command's wrong skill directory name (`smaqit.read-pdf` → `smaqit.utils.read-pdf`) and add the `[SMAQIT_SKILLS_DIR]` placeholder; reword "Use `read_file` on the path..." to generic phrasing.
7. **`skills/smaqit.test-complete/SKILL.md`** and **`skills/smaqit.parity-assess/SKILL.md`**: normalize the remaining informal `` `read_file` `` mentions to generic phrasing.
8. Run `python3 scripts/generate-targets.py`; spot-check that the `[SMAQIT_SKILLS_DIR]` placeholder in read-pdf resolves correctly for both platforms (it wasn't resolved at all before this task, since the hardcoded path skipped it).
9. `make sync` (dogfooding) and `make -C installer build`; end-to-end scratch-dir `init` to confirm no regressions.
10. Update `CHANGELOG.md`; mark this task Completed in `PLANNING.md`.

## Acceptance Criteria

- [x] No skill references a `memory`/`store_memory` tool as a mandatory, unconditional step — all such steps are phrased as "if available, use it; otherwise the file-based record is authoritative"
- [x] `smaqit.session-finish`, `smaqit.session-recap`, `smaqit.session-title` each have a Step 0 that uses native context directly when available, falling back to `{{VSCODE_TARGET_SESSION_LOG}}`-based transcript reading only when needed
- [x] `vscode_askQuestions` no longer appears anywhere in `skills/` — verified via grep
- [x] `smaqit.utils.read-pdf`'s `allowed-tools:` reads `Bash Read`; its example command references the correct skill directory name and uses `[SMAQIT_SKILLS_DIR]`
- [x] No skill in `skills/` references `read_file` as a specific tool name — verified via grep
- [x] `python3 scripts/generate-targets.py` runs clean; `[SMAQIT_SKILLS_DIR]` resolves correctly in read-pdf's compiled output for both platforms — verified directly (`.github/skills/...` vs `.claude/skills/...`)
- [x] `make sync` and `make -C installer build` succeed; end-to-end scratch-dir `init`/`uninstall` show no regressions (65/65 files installed and removed)
- [x] `CHANGELOG.md` updated; `PLANNING.md` marked Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.session-finish/SKILL.md` | Modify — conditional Step 0, generic memory language |
| `skills/smaqit.session-start/SKILL.md` | Modify — generic memory language (2 spots) |
| `skills/smaqit.session-recap/SKILL.md` | Modify — conditional Step 0, generic `read_file` mention |
| `skills/smaqit.session-title/SKILL.md` | Modify — conditional Step 0, generic `read_file` mention |
| `skills/smaqit.task-create/SKILL.md` | Modify — generic memory language |
| `skills/smaqit.task-start/SKILL.md` | Modify — generic memory language |
| `skills/smaqit.task-complete/SKILL.md` | Modify — generic memory language |
| `skills/smaqit.task-plan/SKILL.md` | Modify — generic memory language (7 spots), remove `vscode_askQuestions` (2 spots) |
| `skills/smaqit.utils.read-pdf/SKILL.md` | Modify — fix `allowed-tools:`, fix skill-name self-reference + `[SMAQIT_SKILLS_DIR]`, generic `read_file` mention |
| `skills/smaqit.test-complete/SKILL.md` | Modify — generic `read_file` mention |
| `skills/smaqit.parity-assess/SKILL.md` | Modify — generic `read_file` mentions (2 spots) |
| `CHANGELOG.md` | Modify — add entry |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Findings

**Implementation approach:**
- Confirmed via direct inspection that no Claude Code tool named `memory`/`store_memory` exists in a live tool list, and that Claude's actual memory model is file-based (Read/Write into a memory directory), not a single callable tool with a `type:`/`subject`/`fact` signature — this grounded the "file-based record is authoritative, memory tool is a best-effort accelerant" design rather than inventing a fourth naming convention
- Applied the identical conditional-language pattern across all affected files rather than bespoke wording per skill, so the resulting prose reads consistently across `session-*` and `task-*` skills
- No generator or build-mechanism changes were needed — every fix was plain shared prose, correct verbatim on both `.github/skills/` and `.claude/skills/`, confirmed by diffing compiled output for a non-placeholder skill (`session-finish`) and finding zero difference between platforms

**Decisions made:**
- Kept the subject/fact/citations/reason schema as descriptive guidance in all memory steps rather than deleting it — it's a reasonable, tool-agnostic shape for a memory entry regardless of what (if anything) ultimately stores it
- Left `{{VSCODE_TARGET_SESSION_LOG}}` as literal text in the Copilot-fallback branch of `session-finish`/`session-recap`/`session-title`'s Step 0 rather than resolving or removing it — it's a VS Code runtime substitution outside this repo's build pipeline, and Claude Code simply never takes that branch since native context is checked first
- Corrected `smaqit.utils.read-pdf`'s `allowed-tools:` to real Claude tool names (`Bash Read`) rather than removing the field — it's valid, Claude-Code-only, harmless-if-ignored-by-Copilot syntax; the bug was the wrong values, not the field's presence
- Left the MCP tool reference in `smaqit.parity-assess` (`mcp_github_mcp_se_get_file_contents`) untouched — MCP is a cross-platform protocol, not IDE-specific, so naming an MCP tool isn't the same class of problem as naming a VS Code-specific tool

**Blockers encountered:**
- None

**Follow-up identified:**
- None. This closes out the third and final round of Claude Code compatibility work identified across tasks 012–014; `PLANNING.md`'s remaining open items (002, 007, 010) are unrelated.

## Notes

- This task does not touch `installer/main.go`, `scripts/generate-targets.py`, or any Makefile — pure content edits to shared skill bodies, no build-mechanism changes.
- `{{VSCODE_TARGET_SESSION_LOG}}` itself is left as literal text in the Copilot-fallback branch — it's a Copilot runtime substitution, not ours to resolve, and Claude Code simply won't take that branch.
- Out of scope: auditing agent *frontmatter* `tools:` arrays for similar issues — those are already correctly platform-branched per task 013's `.frontmatter.yaml` mechanism. This task is specifically about tool names hardcoded in skill *body prose*.
