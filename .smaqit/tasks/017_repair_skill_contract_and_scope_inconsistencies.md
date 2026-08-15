---
status: Completed
mode: Assisted
created: "2026-07-24"
started: "2026-08-06"
completed: "2026-08-06"
---

# Repair Skill Contract and Scope Inconsistencies

## Description

Repair several cross-skill inconsistencies discovered while dogfooding session finish, project
research, task completion, and infrastructure task planning in a downstream project.

The most direct defect is in `smaqit.project-research`: its instructions require a four-column
`TOOL / SECTION / URL / LAYER` candidate file, while `verify-urls.sh` parses only three columns.
Because the URL is the final shell variable, the layer is appended to it and every request fails.
The script also lacks executable permission despite being invoked directly, accepts only HTTP
`200`, and does not fall back to GET when a documentation site rejects HEAD.

The task must also reconcile `smaqit.session-finish` with the canonical compendium format, clarify
the user-approval semantics for assisted task completion, and prevent application-specific work
from silently expanding into reusable skill/framework changes without an explicit planning
decision.

## Design Decisions

- **Canonical research record:** Use four TSV input fields
  (`TOOL`, `SECTION`, `URL`, `LAYER`) and five verifier output fields
  (`TOOL`, `SECTION`, `FINAL_URL`, `STATUS_CODE`, `LAYER`) so layer information survives
  liveness verification.
- **HTTP verification:** Treat any final `2xx` response as live. Try HEAD first and retry with a
  bounded, body-discarding GET when HEAD is rejected or inconclusive.
- **Offline regression tests:** Test the verifier against a local HTTP fixture server rather than
  public documentation sites.
- **Compendium authority:** `COMPENDIUM_FORMAT.md` is authoritative. Session finish must not invent
  `Sessions`, `Last Updated`, or other prohibited per-entry metadata.
- **Assisted completion semantics:** An agent may execute task completion after an explicit user
  request but must never self-initiate completion for an assisted task.
- **Framework scope gate:** A project task that proposes changing reusable skills or generated
  skill mirrors must surface that cross-project impact during planning, compare it with
  application-owned placement, and obtain explicit approval.
- **Canonical source and mirrors:** Modify only canonical files under `skills/`; regenerate
  `.github/`, `.agents/`, installer, and other platform outputs with the repository sync tooling.

## Implementation Steps

1. Update `smaqit.project-research/SKILL.md` so its temporary-file input, verifier output, layer
   preservation, accepted HTTP statuses, retry behavior, and failure handling describe one
   internally consistent contract.
2. Update `verify-urls.sh` to parse and validate exactly four TSV fields, preserve `LAYER` in every
   successful output row, reject malformed records clearly, and emit exactly five fields.
3. Make `verify-urls.sh` executable and keep its documented invocation consistent with its file
   mode.
4. Implement bounded HEAD-to-GET fallback, redirect handling, final-URL reporting, and `2xx`
   success classification without downloading response bodies.
5. Add hermetic shell regression tests using a local HTTP server for: four-column parsing,
   project/task layer preservation, redirects, HTTP 200, non-200 `2xx`, HEAD rejection followed by
   GET success, 4xx rejection, unreachable endpoints, malformed rows, and spaces in tool/section
   labels.
6. Update `smaqit.session-finish/SKILL.md` to remove `Sessions` and `Last Updated` instructions and
   delegate compendium entry structure completely to `COMPENDIUM_FORMAT.md`.
7. Reconcile `smaqit.task-complete/SKILL.md` and `references/RULES.md` so both distinguish
   agent-initiated completion from user-invoked completion in assisted mode, with consistent
   examples and failure handling.
8. Add a framework-scope assessment to `smaqit.task-plan/SKILL.md`: modifying reusable skills or
   platform mirrors must be called out as a cross-project decision, application-owned alternatives
   must be considered, and generated mirrors must not be hand-edited.
9. Bump affected skill versions according to semantic impact and update the changelog with the
   repaired contracts and behavioral clarifications.
10. Run the new regression suite, existing installer/sync smoke tests, and `make sync`; verify all
    generated targets match canonical source and contain no unresolved placeholders.

## Known Issues Triage
**Triaged:** 2026-08-06
**Tools searched:** curl
**Result:** Clear

### Blocking Issues
None.

### Advisory Issues
None.

### Historical (Closed)
None.

### Unresolvable Tools
None.

Note: Searched `curl/curl` for open/closed issues on HEAD-request rejection, redirect handling, and HEAD-to-GET fallback semantics (directly relevant to this task's Step 4: bounded HEAD-then-GET fallback). No open bug/regression matches either query. Closed-issue search surfaced six unrelated items (FTP response codes, POST-redirect method changes, TLS/timeout issues) — none describe a limitation in plain HEAD/GET fallback behavior that would affect this task's approach.

## Acceptance Criteria

- [x] `smaqit.project-research` documents one unambiguous four-field input and five-field output contract
- [x] `verify-urls.sh` parses `LAYER` separately and preserves it through redirects and successful output
- [x] `verify-urls.sh` is executable and its documented invocation works without an explicit shell prefix
- [x] Every final `2xx` response is classified as live
- [x] HEAD rejection or inconclusive transport status triggers one bounded GET fallback without retaining the body
- [x] Malformed TSV records fail with a clear diagnostic and do not produce corrupted URL requests
- [x] Hermetic tests cover project/task layers, 200, non-200 `2xx`, redirect, HEAD-to-GET fallback, 4xx, unreachable, malformed, and label-spacing cases
- [x] `smaqit.session-finish` contains no instruction to create or update compendium metadata prohibited by `COMPENDIUM_FORMAT.md`
- [x] `smaqit.task-complete` and `RULES.md` consistently allow user-invoked assisted completion while prohibiting agent self-completion
- [x] `smaqit.task-plan` requires explicit approval and an application-owned alternative assessment before reusable project skills are modified
- [x] Canonical skill versions and `CHANGELOG.md` reflect the contract and behavior changes
- [x] `make sync` regenerates all supported platform targets; canonical and generated copies are consistent
- [x] New regression tests and existing installer/smoke tests pass

## Findings

**Implementation approach:**
- Verified all claimed defects against current file state via Discovery before implementing — three of five (session-finish, task-complete/RULES.md, task-plan) had been touched by other work since this task was written, and one AC (executable bit) turned out already-fixed
- Rewrote `verify-urls.sh` to parse 4 tab-separated fields with explicit malformed-record rejection, accept any `2xx`, and fall back from HEAD to a single bounded GET
- Built a hermetic regression suite against a local Python HTTP fixture server (10 scenarios) rather than public sites, per the task's own design decision
- Reconciled assisted-completion wording in `task-complete/SKILL.md` and `RULES.md`, then discovered `RULES.md` is independently triplicated across `task-start`/`task-complete`/`task-list` (not a shared file) and synced all three
- Added a framework-scope check to `task-plan/SKILL.md` Phase 4 (new step 11a) that surfaces a dedicated Framework Impact section within the same single-approval plan message, rather than a separate gate
- Absorbed the `.claude/` dogfooding-mirror drift-guard scope: extended `make sync` to cover `.claude/{agents,commands,skills}` (root-cause fix) and added independent `assert_tree_matches` checks to `scripts/smoke-test-installer.sh` (detection guard)

**Decisions made:**
- Malformed TSV records (invalid LAYER value, or missing LAYER field) are rejected with a clear diagnostic and no request is attempted — matches the same skip-not-abort philosophy Task 022 established for the task-lifecycle resolver
- Framework Impact gets dedicated visible space in the plan's single approval message rather than a separate confirmation round-trip, consistent with this session's earlier fix collapsing task-plan's redundant double-approval — the two are different in kind (new information vs. mechanical restatement), not in resolution mechanism
- `.claude/` drift guard implemented as both a root-cause fix (extend `sync`) and an independent detection check (smoke-test assertion), since the whole category of bug this task addresses is "the contract says one thing, the mechanism does another"

**Blockers encountered:**
- None

**Follow-up identified:**
- Task 002, 007, 010 remain open and unprioritized
- Consider whether `RULES.md` triplication (task-start/task-complete/task-list) should become a single shared reference instead of three independently-maintained copies, to prevent this exact class of drift recurring

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.project-research/SKILL.md` | Modify — align TSV and liveness-verification contract |
| `skills/smaqit.project-research/scripts/verify-urls.sh` | Modify — four-field parser, layer-preserving output, HTTP fallback; set executable mode |
| `tests/skills/test-project-research-verify-urls.sh` | Create — hermetic verifier regression suite |
| `skills/smaqit.session-finish/SKILL.md` | Modify — remove prohibited compendium metadata instructions |
| `skills/smaqit.project-compendium/references/COMPENDIUM_FORMAT.md` | Verify or clarify as the canonical compendium contract |
| `skills/smaqit.task-complete/SKILL.md` | Modify — clarify user-invoked assisted completion |
| `skills/smaqit.task-complete/references/RULES.md` | Modify — align assisted-mode rules and examples |
| `skills/smaqit.task-start/references/RULES.md` | Modify (discovered during implementation, not in original plan) — RULES.md is independently duplicated across task-start/task-complete/task-list, not shared; synced to match |
| `skills/smaqit.task-list/references/RULES.md` | Modify (discovered during implementation, not in original plan) — same duplication as above |
| `skills/smaqit.task-plan/SKILL.md` | Modify — add reusable-skill/framework scope gate |
| `Makefile` | Modify — expose the hermetic skill regression suite; extend `sync` target to cover `.claude/{agents,commands,skills}` (absorbed drift-guard scope) |
| `scripts/smoke-test-installer.sh` | Modify (absorbed drift-guard scope) — assert root `.claude/` mirror matches canonical, independent of the `sync` fix |
| `CHANGELOG.md` | Modify — document repaired skill contracts |
| Generated platform targets | Regenerate with `make sync`; do not edit manually |

## Notes

- Reproduction evidence came from a downstream `session-finish` run. Passing a documented
  four-column row caused `curl` status `000`; stripping the layer made the same URLs verify.
- Direct execution of the checked-in verifier failed because its mode was `0644`; invoking it
  through `bash` was only a temporary workaround.
- This task fixes framework source in `smaqit-extensions`. Moving already-landed,
  application-specific scripts out of downstream project skill mirrors is separate cleanup, but
  the new `task-plan` gate must prevent the same unreviewed scope expansion.
- Preserve public documentation verification as best-effort behavior: a single unreachable site
  must not prevent the remaining research map from being generated.
