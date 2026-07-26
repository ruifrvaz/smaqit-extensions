# Repair Skill Contract and Scope Inconsistencies

**Status:** Not Started
**Created:** 2026-07-24

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

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `smaqit.project-research` documents one unambiguous four-field input and five-field output contract
- [ ] `verify-urls.sh` parses `LAYER` separately and preserves it through redirects and successful output
- [ ] `verify-urls.sh` is executable and its documented invocation works without an explicit shell prefix
- [ ] Every final `2xx` response is classified as live
- [ ] HEAD rejection or inconclusive transport status triggers one bounded GET fallback without retaining the body
- [ ] Malformed TSV records fail with a clear diagnostic and do not produce corrupted URL requests
- [ ] Hermetic tests cover project/task layers, 200, non-200 `2xx`, redirect, HEAD-to-GET fallback, 4xx, unreachable, malformed, and label-spacing cases
- [ ] `smaqit.session-finish` contains no instruction to create or update compendium metadata prohibited by `COMPENDIUM_FORMAT.md`
- [ ] `smaqit.task-complete` and `RULES.md` consistently allow user-invoked assisted completion while prohibiting agent self-completion
- [ ] `smaqit.task-plan` requires explicit approval and an application-owned alternative assessment before reusable project skills are modified
- [ ] Canonical skill versions and `CHANGELOG.md` reflect the contract and behavior changes
- [ ] `make sync` regenerates all supported platform targets; canonical and generated copies are consistent
- [ ] New regression tests and existing installer/smoke tests pass

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
| `skills/smaqit.project-research/SKILL.md` | Modify — align TSV and liveness-verification contract |
| `skills/smaqit.project-research/scripts/verify-urls.sh` | Modify — four-field parser, layer-preserving output, HTTP fallback; set executable mode |
| `tests/skills/test-project-research-verify-urls.sh` | Create — hermetic verifier regression suite |
| `skills/smaqit.session-finish/SKILL.md` | Modify — remove prohibited compendium metadata instructions |
| `skills/smaqit.project-compendium/references/COMPENDIUM_FORMAT.md` | Verify or clarify as the canonical compendium contract |
| `skills/smaqit.task-complete/SKILL.md` | Modify — clarify user-invoked assisted completion |
| `skills/smaqit.task-complete/references/RULES.md` | Modify — align assisted-mode rules and examples |
| `skills/smaqit.task-plan/SKILL.md` | Modify — add reusable-skill/framework scope gate |
| `Makefile` | Modify if needed — expose the hermetic skill regression suite |
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
