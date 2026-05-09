# Create smaqit.compendium Skill

**Status:** Not Started
**Created:** 2026-05-09

## Description

Create a new `smaqit.compendium` skill that maintains a live Q&A knowledge manifest at `.smaqit/compendium.md`. The compendium grows continuously across sessions: every time a user asks a notable question, the agent captures the question and an approved answer into the manifest. Over time it becomes a retrievable, searchable, and deduplicated knowledge base specific to the project.

Unlike the glossary (which stores term definitions), the compendium stores full Q&A pairs — questions asked by the user, answers provided by the agent, grouped by topic category, with deduplication and semantic grouping logic.

The compendium has two integration points:
1. **`smaqit.session-start`** — loads the full compendium into session context at startup so all knowledge is available immediately without re-querying.
2. **`smaqit.session-finish`** — scans the session for notable questions asked, generates or updates compendium entries, checks for redundancy with existing entries, and merges similar questions before writing.

The skill itself is also directly invocable for explicit operations (list, fetch, remove, manual update).

## Design Decisions (confirmed)

- **Storage path:** `.smaqit/compendium.md` — smaqit-managed, isolated from any manually maintained project docs
- **Entry structure:** Grouped by category; each entry contains: Question, Answer, Last Updated, Session count (how many sessions referenced it)
- **Auto-approval:** Entries are auto-approved on creation — no user confirmation gate; entries are generated from session questions and written atomically
- **Redundancy handling:** Before writing a new entry, the agent checks for semantically similar existing entries and either: (a) merges similar questions into a single canonical entry with the best combined answer, or (b) adds a cross-reference if two questions are related but distinct
- **Session-finish integration:** `smaqit.session-finish` gains a new step that scans the session transcript for user questions, evaluates each against the compendium for novelty, and writes/updates entries
- **Session-start integration:** `smaqit.session-start` loads the full `.smaqit/compendium.md` into context at startup (conditional — skipped silently if file does not exist)
- **Search mode:** Semantic ranking for `fetch from compendium` — the agent evaluates query relevance against all questions and returns the best match(es), not just keyword hits
- **Agentic deduplication:** The skill is agentic — the agent reasons about semantic similarity rather than relying on exact string matching

## Skill Interface (trigger phrases)

All four triggers must be listed in the frontmatter description for reliable Copilot skill matching:
- `list compendium` — display all Q&A entries grouped by category in a formatted table
- `fetch from compendium [query]` — semantic search for the most relevant entry/entries to the query
- `update compendium [question]` — manually add or update a specific Q&A entry (upsert semantics)
- `remove from compendium [question]` — delete an entry after confirmation

## Compendium File Format

```markdown
# Project Compendium

Last updated: YYYY-MM-DD | Total entries: N

## [Category Name]

| Question | Answer | Last Updated | Sessions |
|----------|--------|-------------|----------|
| How do I release a new version? | Run `smaqit.release.local` agent... | 2026-05-09 | 3 |
```

Categories are inferred by the agent based on the nature of the question (e.g., "Release Workflow", "Task Management", "Installation", "Architecture"). New categories are created as needed. The agent may reorganize categories when merging entries if existing categorization no longer fits.

## Integration: smaqit.session-finish

Add a new step to `smaqit.session-finish` (after history file is written):

**Step: Compendium Update**
1. Scan the session transcript for questions asked by the user — identify questions that are project-specific, non-trivial, and answered substantively by the agent
2. Filter out: purely navigational questions (e.g., "what's next?"), one-word commands, and questions that are meta-session (e.g., "new session")
3. For each candidate question: check `.smaqit/compendium.md` for semantically similar existing entries
4. If similar entry found: merge or update — rewrite the answer to incorporate new information, increment Sessions counter, update Last Updated date
5. If no similar entry found: create new entry, assign appropriate category, set Sessions to 1
6. Write the updated compendium atomically (overwrite the file)
7. Report: "Compendium updated — N entries added, M entries updated"

## Integration: smaqit.session-start

Add a conditional step (after glossary load, before synthesis):

**Step: Compendium Load**
- Check if `.smaqit/compendium.md` exists
- If yes: read the full file and surface all Q&A entries in context
- If no: skip silently
- The loaded entries are available to the agent throughout the session for reference and consistency

## Acceptance Criteria

- [ ] `skills/smaqit.compendium/SKILL.md` created with correct frontmatter: `name: smaqit.compendium`, description enumerating all four trigger phrases, `metadata.version: "0.1.0"`
- [ ] Trigger `list compendium` — displays all entries grouped by category in markdown table format; handles empty/missing compendium gracefully
- [ ] Trigger `fetch from compendium [query]` — performs semantic evaluation of query against all Q&A pairs and returns the most relevant match(es) with relevance reasoning
- [ ] Trigger `update compendium [question]` — upsert semantics: adds entry if absent, edits if semantically equivalent question already exists; prompts user for answer if not provided inline
- [ ] Trigger `remove from compendium [question]` — requires user confirmation before deletion; removes the entry and cleans up empty category sections
- [ ] Compendium format defined: `.smaqit/compendium.md` with markdown table grouped by category (Question | Answer | Last Updated | Sessions)
- [ ] Skill handles missing compendium file gracefully on all read operations (no crash, informative message)
- [ ] Skill creates the compendium file on first write (does not require pre-existing file)
- [ ] Deduplication: before creating a new entry, the agent checks for and handles semantic duplicates (merge or cross-reference)
- [ ] `skills/smaqit.session-finish/SKILL.md` updated with compendium update step (scan session, evaluate novelty, write/merge entries)
- [ ] `skills/smaqit.session-start/SKILL.md` updated with conditional compendium load step (reads full file into context if present)
- [ ] Version bumped in frontmatter of all modified skills (`session-finish`, `session-start`)
- [ ] All files synced to `.github/` via `make sync`
- [ ] `README.md` updated: skill added to Session Management or new Knowledge section; skill count incremented
- [ ] PLANNING.md updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.compendium/SKILL.md` | Create |
| `skills/smaqit.compendium/references/COMPENDIUM_FORMAT.md` | Create — entry format template and deduplication rules |
| `.github/skills/smaqit.compendium/SKILL.md` | Synced via `make sync` |
| `.github/skills/smaqit.compendium/references/COMPENDIUM_FORMAT.md` | Synced via `make sync` |
| `skills/smaqit.session-finish/SKILL.md` | Modify — add compendium update step |
| `skills/smaqit.session-start/SKILL.md` | Modify — add compendium load step |
| `.github/skills/smaqit.session-finish/SKILL.md` | Synced via `make sync` |
| `.github/skills/smaqit.session-start/SKILL.md` | Synced via `make sync` |
| `README.md` | Modify — add skill, increment count |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- The compendium is not a verbatim log — the agent should synthesize clean, reusable Q&A pairs, not copy raw session dialogue
- The session-finish step should err on the side of inclusion for novel questions, and err on the side of merging for similar questions
- Session counter (`Sessions`) is important for surfacing frequently-asked questions and understanding knowledge gaps
- Long answers are acceptable in the compendium — the format supports multi-line markdown in table cells
- Do not add URLs to entries. Keep answers self-contained and reference file paths or skill names instead of external links
- **Progressive disclosure (spec requirement):** Keep `SKILL.md` under 500 lines and 5,000 tokens. The compendium file format specification, entry format details, and the full session-finish integration logic are substantial — move the entry format template and session-finish scanning rules to `references/COMPENDIUM_FORMAT.md` and reference it conditionally: "Read `references/COMPENDIUM_FORMAT.md` for the full entry format and deduplication rules before writing to the compendium."
- **Gotchas to include in SKILL.md:** (1) `.smaqit/compendium.md` may not exist on first run — always create it on first write, never error on absence; (2) markdown table cells with multi-line answers require `<br>` for line breaks within a cell — the agent must use this for formatted answers rather than raw newlines; (3) the session-finish scan must filter out meta-session questions ("new session", "what's next", "can you recap") — these are navigation, not knowledge.
