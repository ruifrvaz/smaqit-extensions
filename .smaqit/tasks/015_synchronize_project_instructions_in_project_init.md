# Synchronize Project Instructions in Project Init

**Status:** Completed
**Mode:** Assisted
**Created:** 2026-07-22
**Started:** 2026-07-22
**Completed:** 2026-07-23

## Description

Change `smaqit.project-init` so an existing project-instructions file is input to initialization rather than a reason to abort. The skill must use model inference to read the project's existing Codex, Claude Code, and GitHub Copilot instructions together with repository evidence and the installed smaqit template, then rewrite them as one coherent, grounded instruction set without implementing semantic merging in a deterministic script.

The synchronized topology uses root `AGENTS.md` as the canonical merged document. Root `CLAUDE.md` imports it with `@AGENTS.md` and retains only genuinely Claude-specific additions. `.github/copilot-instructions.md` is a relative symlink to `../AGENTS.md`; any distinct content in a pre-existing regular file or different symlink target must be preserved in the canonical merge before replacement.

## Design Decisions

- **Canonical source:** `AGENTS.md` is the single canonical merged instruction document shared across Codex, Claude Code, and GitHub Copilot.
- **Claude specificity:** `CLAUDE.md` contains `@AGENTS.md` plus only Claude-specific directives that cannot live in the shared document.
- **Copilot specificity:** `.github/copilot-instructions.md` is a relative symlink to `../AGENTS.md`; Copilot-specific content is retained in clearly scoped sections of the canonical document.
- **Inferential merge:** The host model performs the semantic read, preservation, deduplication, organization, and rewrite. Go, Python, and shell code may distribute and validate the skill but must not implement the content merge.
- **Preservation precedence:** Explicit existing project instructions are authoritative. The current template is authoritative within smaqit-owned scaffolding content, and inferred repository facts fill gaps only when evidence is clear.
- **Conflict safety:** File existence alone never blocks initialization. If explicit instructions conflict irreconcilably, the skill surfaces the conflict and requests user direction before writing.
- **Safe migration order:** Write and validate canonical `AGENTS.md` before replacing a populated Copilot file with the symlink. If symlink creation is unsupported, report the failure rather than silently creating a divergent copy.
- **Backward-compatible template:** Keep `.smaqit/templates/copilot-instructions.template.md` as the installed template path; renaming or migrating already-installed templates is out of scope.
- **Supported tools:** This task covers Codex, Claude Code, and GitHub Copilot. Cursor support is out of scope.
- **Workflow mode:** Assisted; the user reviews the inference contract and fixture results before completing the task.

## Implementation Steps

1. Rewrite the canonical `smaqit.project-init` skill and bump its version from 0.4.0 to 0.5.0. Remove the existing-file hard stop and require every invocation to inspect all three instruction paths, resolving symlinks without treating shared content as separate input.
2. Specify the inference contract: preserve explicit rules, semantically deduplicate repeated guidance, retain platform-only material under appropriate scopes, refresh the smaqit-owned Scaffolding section, infer project context only from repository evidence, and avoid unsupported claims.
3. Specify the safe output transaction: produce `AGENTS.md` first, write the minimal `CLAUDE.md` importer with Claude-only additions, then migrate `.github/copilot-instructions.md` to the `../AGENTS.md` symlink only after its unique content is represented in the canonical file. Include rollback/reporting behavior for failed symlink creation.
4. Make repeated initialization idempotent: do not duplicate headings, imports, platform sections, template content, or inferred facts; keep a correct symlink unchanged; avoid semantic churn when the inputs are unchanged.
5. Remove the obsolete active-platform `{{INSTRUCTIONS_FILE}}` substitution and its definition once the skill names and synchronizes all three paths directly.
6. Regenerate all Copilot, Claude, and Codex skill distributions and confirm their `smaqit.project-init` bodies carry the same synchronization contract.
7. Update README and CHANGELOG documentation to describe the canonical topology, inferential migration behavior, conflict handling, and symlink limitation.
8. Extend installer smoke assertions to reject the old abort language and verify the generated skill contract, Claude importer, Copilot relative symlink, and absence of unresolved placeholders.
9. Exercise model-mediated fixtures in isolated, locally installed temporary projects: no existing files; only `AGENTS.md`; three populated files with unique sentinel rules; a regular Copilot file; correct, incorrect, and broken symlinks; an irreconcilable conflict; and a second invocation for idempotency. Deterministic setup and assertions are allowed, but the agent must perform each semantic merge.
10. Run generation, installer tests, full smoke testing, Go vetting, shell checks, and whitespace validation. Record any platform limitation or follow-up exposed by the model-mediated runs.

## Known Issues Triage

**Triaged:** 2026-07-22
**Tools searched:** Claude Code, GitHub Copilot, OpenAI Codex
**Result:** Blocking

### Blocking Issues
- [#78697 @import in an ancestor CLAUDE.md does not expand (subdirectory launch)](https://github.com/anthropics/claude-code/issues/78697) — `anthropics/claude-code` — opened 2026-07-17 — bug, has repro, platform:macos, area:core
- [#78216 [BUG] @imports in a parent-directory CLAUDE.md are silently ignored](https://github.com/anthropics/claude-code/issues/78216) — `anthropics/claude-code` — opened 2026-07-16 — bug, platform:macos, area:core

### Advisory Issues
- [#66559 [BUG] Claude refuses to write CLAUDE.md when it's a symlink](https://github.com/anthropics/claude-code/issues/66559) — `anthropics/claude-code` — opened 2026-06-09 — bug, has repro, api:bedrock, platform:linux, area:tools, area:security
- [#6235 Feature Request: Support AGENTS.md](https://github.com/anthropics/claude-code/issues/6235) — `anthropics/claude-code` — opened 2025-08-21 — enhancement, area:core, memory

### Historical (Closed)
- None directly relevant.

### Unresolvable Tools
- None. `openai/codex` was selected as the official Codex repository after generic repository search returned an unrelated project.

## Acceptance Criteria

- [x] Existing `AGENTS.md`, `CLAUDE.md`, or `.github/copilot-instructions.md` never causes initialization to stop merely because the file exists.
- [x] The skill reads all existing instruction sources and repository evidence before writing, and no deterministic script implements semantic merging.
- [x] Unique explicit project rules from every existing instruction source remain materially intact in the synchronized result.
- [x] Root `AGENTS.md` is the coherent canonical document with current smaqit scaffolding and only evidence-grounded project facts.
- [x] Root `CLAUDE.md` starts with `@AGENTS.md` and contains no duplicated shared guidance, while preserving genuinely Claude-specific directives.
- [x] `.github/copilot-instructions.md` is a relative symlink to `../AGENTS.md`, created only after its prior unique content is safely represented in `AGENTS.md`.
- [x] Irreconcilable explicit conflicts cause a focused user decision request before any instruction file is rewritten.
- [x] A second initialization with unchanged inputs preserves the symlink and produces no duplicate content or meaningful semantic churn.
- [x] All generated and installed platform variants contain the same synchronization contract, with no old abort behavior or unresolved `{{INSTRUCTIONS_FILE}}` placeholder.
- [x] Model-mediated temporary-project fixtures cover fresh creation, populated-file migration, symlink migration, conflict handling, and idempotency without losing sentinel rules.
- [x] README and CHANGELOG describe the new behavior and topology.
- [x] Target generation, installer unit tests, full smoke tests, `go vet`, shell checks, and `git diff --check` pass.

## Findings

**Implementation approach:**
- Replaced the single-platform existing-file abort with an inference-driven workflow that reads all instruction sources before writing a canonical result.
- Retired the active-platform filename placeholder, regenerated identical platform variants, and added installer smoke assertions for the shared contract.
- Verified fresh creation, populated-file migration, conflict safety, and idempotency through isolated model-mediated fixtures in addition to deterministic build gates.

**Decisions made:**
- Made root `AGENTS.md` canonical, kept Claude-specific guidance behind an `@AGENTS.md` importer, and made the Copilot path a relative symlink.
- Gave explicit project rules precedence over inference and required unresolved contradictions to stop before mutation.
- Retained the existing installed template path for backward compatibility.

**Blockers encountered:**
- Claude Code has upstream ancestor-import bugs that may affect sessions launched from repository subdirectories; the user explicitly accepted this limitation.
- GitHub Actions runner degradation delayed the v1.7.0 release workflow, but did not affect implementation validation or publication.

**Follow-up identified:**
- Monitor Claude Code ancestor-import fixes and revisit the root-launch warning when upstream behavior is reliable.
- Template migration for already-installed projects remains a separate concern if the shared template later requires versioned upgrades.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.project-init/SKILL.md` | Modify — inferential three-file synchronization contract and version bump |
| `.smaqit/definitions/skills/smaqit.project-init.placeholders.yaml` | Delete — active-platform filename substitution becomes obsolete |
| `.github/skills/smaqit.project-init/SKILL.md` | Regenerate — Copilot distribution |
| `.claude/skills/smaqit.project-init/SKILL.md` | Regenerate — Claude distribution |
| `.agents/skills/smaqit.project-init/SKILL.md` | Regenerate — Codex distribution |
| `installer/skills*/smaqit.project-init/SKILL.md` | Regenerate — embedded installer distributions |
| `scripts/smoke-test-installer.sh` | Modify — synchronization-contract assertions and topology checks |
| `README.md` | Modify — document canonical synchronized instructions |
| `CHANGELOG.md` | Modify — record the project-init behavior change |
| `.smaqit/tasks/PLANNING.md` | Modify — task lifecycle tracking |

## Notes

- Claude Code supports importing another instruction file with `@AGENTS.md`: https://code.claude.com/docs/en/memory
- GitHub Copilot instruction-file support varies by surface; the relative symlink is the project's selected repository convention: https://docs.github.com/en/copilot/reference/custom-instructions-support
- The installed template's existing write-if-missing upgrade policy is not changed by this task.
- The user explicitly accepted proceeding despite Claude Code issues #78697 and #78216. The implementation must document and test the known nested-launch limitation rather than changing the agreed importer topology.
