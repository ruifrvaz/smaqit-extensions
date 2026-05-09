# Refine smaqit.project-research Skill

**Status:** Completed
**Created:** 2026-05-09
**Completed:** 2026-05-09

## Description

Refine the existing `smaqit.project-research` skill to address two problems:

**Problem 1 — Static map:** The research map is currently designed as a one-off flat document ("built once and reused"). There is no mechanism to continuously update it or detect staleness. As dependencies are added, documentation URLs move, or platforms evolve, the map silently becomes outdated. Users must manually delete it or re-invoke the skill to get fresh data.

**Problem 2 — GitHub-centric discovery:** The current URL discovery pipeline explicitly names `github_repo` and `github_text_search` as primary tools. There is no fallback for tools whose documentation lives on ReadTheDocs, official docs sites (docs.tool.io patterns), API portals, npm docs, or other public platforms.

Both problems are addressed through targeted updates to the skill's SKILL.md — no new scripts or reference files are needed. The fix is instruction-level with a minor version bump.

## Design Decisions (confirmed)

- **Refresh trigger:** Triggered at `smaqit.session-finish` (runs automatically at end of every session) AND also manually invocable by the user (`project.research --refresh` or `project.research` re-invocation). This ensures the map stays current without user remembering to invoke it.
- **Multi-platform discovery:** Agent knowledge + best-guess patterns. No structured `.smaqit/doc-platforms.md` registry. The agent should try known URL patterns for tools it doesn't find on GitHub: `docs.{tool}.io`, `{tool}.readthedocs.io`, `github.com/{tool}/{tool}/wiki`, npm/PyPI doc links.
- **Scope:** Public docs only. No private/internal platforms (Confluence, GitLab self-hosted, internal wikis) in this iteration.
- **Version bump:** `1.1.0 → 1.2.0` (MINOR — new behavior, no breaking changes to output format)

## Changes to smaqit.project-research SKILL.md

### Change 1: Description update

Update the frontmatter `description` to communicate that the skill runs continuously (not just on demand):

**Current description (approximate):**
> "Builds and maintains a documentation topology map for the current project. ... Invoke explicitly with `project.research` or `project.research [task-id]`, or automatically from `smaqit.task-start` when the research map is absent."

**New description (add):**
- Mention that the skill is also triggered at session-finish to refresh the map
- Mention multi-platform discovery (not just GitHub)

### Change 2: Step 1 — Staleness detection

Add to the opening step: before deciding whether to build or reuse the existing map, check the map's last-updated date. If the map is older than a configurable threshold (default: 7 days) OR if any project manifest file is newer than the map's last-updated date, treat the map as absent and rebuild.

The map header should include a `Last updated:` timestamp (already present in RESEARCH_MAP.md template — verify this; if not, add it). The skill must write this timestamp on every update.

### Change 3: Step 3 — Multi-platform URL discovery

Expand the URL discovery chain from GitHub-only to a platform-aware cascade:

1. **GitHub first** (existing): use `github_repo` and `github_text_search` to find the tool's repository and any associated GitHub Pages docs
2. **Official docs site (agent knowledge)**: if the agent knows the tool's canonical docs URL, use it directly (e.g., `docs.docker.com`, `docs.python.org`, `go.dev/doc`)
3. **Best-guess patterns (fallback)**: try standard URL patterns in this order:
   - `https://docs.{tool-name}.io`
   - `https://{tool-name}.readthedocs.io`
   - `https://pkg.go.dev/{module-path}` (for Go modules)
   - `https://www.npmjs.com/package/{package-name}` (for npm packages)
   - `https://pypi.org/project/{package-name}` (for Python packages)
4. **GitHub wiki (last resort)**: `https://github.com/{owner}/{repo}/wiki`
5. **Mark Unknown**: if no URL is found through any of these strategies, mark the tool as `Unknown` in the research map rather than omitting it

### Change 4: session-finish integration

Add a step to `smaqit.session-finish` (after compendium update, before session history write) that triggers a project-research refresh:

**Step: Research Map Refresh**
1. Check if `.smaqit/references/project-research.md` exists
2. If it exists: read the `Last updated:` date from the map header
3. If the map is older than 7 days OR any manifest file (go.mod, package.json, requirements.txt, etc.) is newer than the map: invoke `smaqit.project-research` to rebuild
4. If the map is current: skip silently, report "Research map is current (last updated: YYYY-MM-DD)"
5. If the map does not exist: invoke `smaqit.project-research` to build it for the first time

## Acceptance Criteria

- [x] `skills/smaqit.project-research/SKILL.md` version bumped to `1.2.0`
- [x] Frontmatter description updated to mention session-finish trigger and multi-platform discovery
- [x] Step 1 (or new Step 0) includes staleness check: compare map's `Last updated:` date against current date and manifest modification times
- [x] Staleness threshold documented in skill: 7 days (configurable via instruction, not hardcoded)
- [x] Step 3 (URL discovery) expanded to include the full platform-aware cascade: GitHub → agent knowledge → best-guess patterns → GitHub wiki → Unknown fallback
- [x] `skills/smaqit.project-research/references/DOC_PLATFORMS.md` created with the full platform-aware URL pattern catalogue (one section per ecosystem: docs.{tool}.io, readthedocs.io, pkg.go.dev, npmjs.com, pypi.org, GitHub wiki)
- [x] SKILL.md includes a brief summary of the cascade strategy with a conditional reference to `references/DOC_PLATFORMS.md` for the full pattern list
- [x] `skills/smaqit.session-finish/SKILL.md` updated with research map refresh step (staleness check → conditional rebuild)
- [x] `skills/smaqit.session-finish/SKILL.md` version bumped
- [x] Research map output format unchanged (no breaking change to RESEARCH_MAP.md template)
- [x] `project.research --refresh` flag documented: forces full rebuild regardless of staleness
- [x] All modified files synced to `.github/` via `make sync`
- [x] PLANNING.md updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.project-research/SKILL.md` | Modify — description, staleness check, multi-platform discovery; bump to v1.2.0 |
| `.github/skills/smaqit.project-research/SKILL.md` | Synced via `make sync` |
| `skills/smaqit.session-finish/SKILL.md` | Modify — add research map refresh step; bump version |
| `.github/skills/smaqit.session-finish/SKILL.md` | Synced via `make sync` |
| `skills/smaqit.project-research/references/DOC_PLATFORMS.md` | Create — platform-aware URL pattern catalogue |
| `.github/skills/smaqit.project-research/references/DOC_PLATFORMS.md` | Synced via `make sync` |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- The RESEARCH_MAP.md template in `skills/smaqit.project-research/references/` must include a `Last updated:` field in the output header. Verify this exists; if not, add it as part of this task.
- The session-finish integration must be defensive: if project-research invocation fails (e.g., tool unavailable), session-finish must complete normally — research refresh is best-effort.
- The 7-day threshold is a reasonable default for most projects. The skill instructions should note that users can override by running `project.research --refresh` at any time.
- The multi-platform fallback chain should not block skill execution — if all pattern attempts fail for a tool, mark it Unknown and continue.
- Do not add private or authenticated documentation sources. Public web only.
- **Dependency on Task 005:** Change 4 describes the research refresh step in `session-finish` as running "after compendium update". This step ordering only applies if Task 005 (smaqit.compendium) has been completed first and the compendium update step exists in `session-finish`. If implementing Task 008 before Task 005, place the research refresh step at the end of `session-finish` (before history write) with a note that it will be re-ordered when Task 005 is implemented.
- **Progressive disclosure (spec requirement):** The updated SKILL.md is an instruction-level modification — keep it under 500 lines. The multi-platform URL pattern catalogue (all the fallback URL patterns per ecosystem) is too large to live inline. Move the full platform pattern reference to `references/DOC_PLATFORMS.md` and reference it conditionally: "Read `references/DOC_PLATFORMS.md` for the full platform-aware URL discovery pattern catalogue when a tool's docs are not found on GitHub."
