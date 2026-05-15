---
name: smaqit.project-compendium
description: Manages a live Q&A knowledge manifest at `.smaqit/compendium.md`. Invoked when the user says `list compendium`, `fetch from compendium [query]`, `update compendium [question]`, or `remove from compendium [question]`. Lists all Q&A entries grouped by category, semantically searches for relevant entries, upserts a Q&A pair (add or update), or removes an entry after confirmation.
metadata:
  version: "0.4.0"
---

# Project Compendium

## Gotchas

1. Unlike the glossary (which stores term definitions), the compendium stores full Q&A pairs — questions asked during sessions, answered by the agent, grouped by topic category, with semantic deduplication.
2. **Before writing to the compendium**, read `references/COMPENDIUM_FORMAT.md` for the full entry format specification and deduplication rules.
3. `.smaqit/compendium.md` may not exist on first run — always create it on first write; never error on absence.
4. The session-finish scan must filter out meta-session questions ("new session", "what's next?", "can you recap?") — these are navigation commands, not knowledge.

---

## Steps

### Compendium File Format

**Path:** `.smaqit/compendium.md`

Entries are stored as section-based markdown: each category is a `## Heading`, questions are bolded (`**Question**`), and answers are normal markdown prose below each question, separated by `---`. There are no tables, no per-entry dates, and no session counters. See `assets/COMPENDIUM_TEMPLATE.md` for the placeholder structure and `references/COMPENDIUM_FORMAT.md` for the full specification.

---

### Trigger: `list compendium`

1. Check if `.smaqit/compendium.md` exists.
   - Does not exist → respond: "No compendium found at `.smaqit/compendium.md`. Use `update compendium` to add the first entry." Stop.
2. Read `.smaqit/compendium.md`.
3. Present all entries grouped by category.
   - File exists but contains no entries → respond: "Compendium exists but contains no entries yet."

---

### Trigger: `fetch from compendium [query]`

1. Parse the query from the user's message. If absent, ask: "What would you like to look up in the compendium?"
2. Check if `.smaqit/compendium.md` exists. If not, respond: "No compendium found. Use `update compendium` to create one."
3. Read `.smaqit/compendium.md`. Evaluate the query semantically against all question headings and answers — find the most relevant match(es) by meaning, not just keyword overlap.
4. If match(es) found: present the question(s), answer(s), and category, with a brief note on why each is relevant.
5. If no relevant match found: inform the user and suggest `update compendium [question]` to add it.

---

### Trigger: `update compendium [question]`

Upsert: add a new entry if no semantically equivalent question exists; update if one does.

Read `references/COMPENDIUM_FORMAT.md` before writing.

1. Parse the question from the user's message. If absent, ask: "What question would you like to add or update?"
2. If no answer provided inline, ask for it.
3. Infer the category from the question's topic. If `.smaqit/compendium.md` exists, list existing categories as suggestions. Default to `General` if unclear.
4. If `.smaqit/compendium.md` does not exist: create it from the template (`assets/COMPENDIUM_TEMPLATE.md`) and add the new entry.
5. If `.smaqit/compendium.md` exists:
   - Check all existing question headings for semantic equivalence with the new question.
   - Semantically equivalent question found: update its answer to the best combined version. Update the question text to whichever phrasing is clearer.
   - No equivalent found: append entry to the correct category section; create the section if absent.
6. Write updated content to `.smaqit/compendium.md`.
7. Confirm: state whether the entry was added or updated, and which category it was placed in.

---

### Trigger: `remove from compendium [question]`

1. Parse the question from the user's message. If absent, ask: "Which entry would you like to remove?"
2. Check if `.smaqit/compendium.md` exists. If not, respond: "No compendium found. Nothing to remove."
3. Read `.smaqit/compendium.md`. Search for the entry (semantic match against bolded question headings).
4. Not found → inform the user the entry does not exist.
5. Found → ask for confirmation: "Remove **[question]** ([category])? Reply `yes` to confirm."
6. On confirmation: remove the entry (bolded question heading, answer, and `---` separator). If the category section becomes empty after removal, remove the entire section (heading and any trailing separator).
7. Write updated content to `.smaqit/compendium.md`. Confirm removal.
8. No confirmation → abort; do not modify the file.

---

## Session-Finish Integration

When `smaqit.session-finish` runs, it executes the following compendium update step after the history file is written:

1. Scan the session transcript for user questions — identify questions that are project-specific, non-trivial, and were answered substantively by the agent.
2. Filter out: purely navigational questions ("what's next?", "can you recap?", "new session"), one-word commands, and meta-session phrases.
3. For each candidate question: check `.smaqit/compendium.md` for semantically similar existing entries.
4. If similar entry found: merge or update — rewrite the answer to incorporate new information.
5. If no similar entry found: create new entry, assign appropriate category.
6. Write the updated compendium atomically (overwrite the file).
7. Report: "Compendium updated — N entries added, M entries updated."

Read `references/COMPENDIUM_FORMAT.md` before writing any entries.

---

## Session-Start Integration

When `smaqit.session-start` runs, it executes the following compendium load step after the glossary step:

- Check if `.smaqit/compendium.md` exists.
- If yes: read the full file and surface all Q&A entries in context so they are available throughout the session.
- If no: skip silently.

---

## Output

- `.smaqit/compendium.md` — created or updated by `update compendium`; updated by `remove from compendium`
- Formatted text responses for `list compendium` and `fetch from compendium`

## Scope

**In scope:**
- All four operations on `.smaqit/compendium.md`
- Category grouping by inferred topic
- Semantic deduplication and merging of similar questions
- Session-finish and session-start integration points

**Out of scope:**
- Syncing to or from any other file
- Auto-discovering questions from codebase
- Bulk import or export
- External URL references in answers

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| `.smaqit/compendium.md` does not exist on a read operation | Inform user; suggest `update compendium` to create it |
| Entry not found on fetch or remove | State the question; suggest `update compendium [question]` to add it |
| User does not confirm removal | Abort; do not modify the file |
| File write fails | Report the error and the intended change so the user can apply it manually |
