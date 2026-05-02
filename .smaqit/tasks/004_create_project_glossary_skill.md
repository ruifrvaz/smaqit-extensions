# Create smaqit.project-glossary Skill

**Status:** Not Started
**Created:** 2026-05-02

## Description

Create a new `smaqit.project-glossary` skill in `smaqit-extensions` that manages a per-project glossary file during agent sessions. The skill handles four operations via keyword triggers: listing all terms, fetching a specific term, updating (upsert) a term, and removing a term.

The skill also requires a complementary update to `smaqit.session-start` so that the glossary is automatically loaded into agent context at session start — making terms available throughout the session without explicit invocation.

## Design Decisions (confirmed)

- **Storage path:** `.smaqit/glossary.md` — smaqit-managed, avoids collisions with manually-maintained `docs/glossary.md`
- **Entry structure:** Term + Definition + Category (3-field markdown table, grouped by category)
- **`update glossary` semantics:** Upsert — adds the term if absent, edits if it exists
- **"Refreshed" mechanism:** `smaqit.session-start` loads the glossary into context at session start
- **Description overloading:** Accepted — all four triggers listed explicitly in the skill description for reliable Copilot skill matching

## Acceptance Criteria

- [ ] `skills/smaqit.project-glossary/SKILL.md` created with correct frontmatter, description listing all four trigger phrases, and implementation steps for all four operations
- [ ] Trigger phrases handled: `list glossary`, `fetch from glossary`, `update glossary`, `remove from glossary`
- [ ] `update glossary` implements upsert semantics (adds new term or edits existing)
- [ ] Glossary file format defined: `.smaqit/glossary.md` with markdown table grouped by category (Term | Definition | Category)
- [ ] Skill handles missing glossary file gracefully (creates it on first write)
- [ ] `skills/smaqit.session-start/SKILL.md` updated to include an optional glossary load step (read `.smaqit/glossary.md` if it exists and surface terms in context)
- [ ] Both files synced to `.github/` via `make sync`
- [ ] Versions bumped in frontmatter of all modified skills

## Notes

The skill description must enumerate all trigger phrases explicitly to compensate for Copilot's single-description matching limitation. Example description pattern:

> "Manages a per-project glossary at `.smaqit/glossary.md`. Use for: list glossary, fetch from glossary, update glossary, remove from glossary."

`smaqit.session-start` change is a soft dependency: glossary load step should be conditional (only runs if `.smaqit/glossary.md` exists) so existing projects without a glossary are unaffected.
