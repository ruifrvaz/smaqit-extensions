---
name: smaqit.compendium
description: Manages a live Q&A knowledge manifest at `.smaqit/compendium.md`. Invoked when the user says `list compendium`, `fetch from compendium [query]`, `update compendium [question]`, or `remove from compendium [question]`. Lists all Q&A entries grouped by category, semantically searches for relevant entries, upserts a Q&A pair (add or update), or removes an entry after confirmation.
metadata:
  version: "0.1.0"
---

# Project Compendium

## Purpose

Manages `.smaqit/compendium.md` as a per-project Q&A knowledge base. Supports four operations triggered by explicit phrases in the user's message: listing all entries, fetching entries by semantic query, upserting a Q&A pair (add if absent, update if semantically equivalent question exists), and removing an entry with confirmation. The compendium file is the sole artifact this skill reads or writes.

Unlike the glossary (which stores term definitions), the compendium stores full Q&A pairs — questions asked during sessions, answered by the agent, grouped by topic category, with semantic deduplication.

> **Before writing to the compendium**, read `references/COMPENDIUM_FORMAT.md` for the full entry format specification and deduplication rules.

## Gotchas

1. `.smaqit/compendium.md` may not exist on first run — always create it on first write; never error on absence.
2. Markdown table cells with multi-line answers require `<br>` for line breaks within a cell — use `<br>` for formatted answers, not raw newlines.
3. The session-finish scan must filter out meta-session questions ("new session", "what's next?", "can you recap?") — these are navigation commands, not knowledge.

---

## Steps

### Compendium File Format

**Path:** `.smaqit/compendium.md`

Entries are stored as Markdown tables with four columns (`Question`, `Answer`, `Last Updated`, `Sessions`), grouped into sections by category. Each category is a `## Heading`. New categories are inferred from the nature of the question. See `references/COMPENDIUM_FORMAT.md` for the full specification.

---

### Trigger: `list compendium`

1. Check if `.smaqit/compendium.md` exists.
   - Does not exist → respond: "No compendium found at `.smaqit/compendium.md`. Use `update compendium` to add the first entry." Stop.
2. Read `.smaqit/compendium.md`.
3. Present all entries grouped by category in formatted tables.
   - File exists but contains no entries → respond: "Compendium exists but contains no entries yet."

---

### Trigger: `fetch from compendium [query]`

1. Parse the query from the user's message. If absent, ask: "What would you like to look up in the compendium?"
2. Check if `.smaqit/compendium.md` exists. If not, respond: "No compendium found. Use `update compendium` to create one."
3. Read `.smaqit/compendium.md`. Evaluate the query semantically against all Question cells — find the most relevant match(es) by meaning, not just keyword overlap.
4. If match(es) found: present the question(s), answer(s), category, and last-updated date, with a brief note on why each is relevant.
5. If no relevant match found: inform the user and suggest `update compendium [question]` to add it.

---

### Trigger: `update compendium [question]`

Upsert: add a new entry if no semantically equivalent question exists; update if one does.

Read `references/COMPENDIUM_FORMAT.md` before writing.

1. Parse the question from the user's message. If absent, ask: "What question would you like to add or update?"
2. If no answer provided inline, ask for it.
3. Infer the category from the question's topic. If `.smaqit/compendium.md` exists, list existing categories as suggestions. Default to `General` if unclear.
4. If `.smaqit/compendium.md` does not exist: create it with the standard header and the new entry (Sessions = 1, Last Updated = today).
5. If `.smaqit/compendium.md` exists:
   - Check all existing Question cells for semantic equivalence with the new question.
   - Semantically equivalent question found: update its Answer to the best combined version, increment Sessions, update Last Updated. Update the Question text to whichever phrasing is clearer.
   - No equivalent found: append entry to the correct category section; create the section if absent.
6. Write updated content to `.smaqit/compendium.md`.
7. Confirm: state whether the entry was added or updated, and which category it was placed in.

---

### Trigger: `remove from compendium [question]`

1. Parse the question from the user's message. If absent, ask: "Which entry would you like to remove?"
2. Check if `.smaqit/compendium.md` exists. If not, respond: "No compendium found. Nothing to remove."
3. Read `.smaqit/compendium.md`. Search for the entry (semantic match against Question column).
4. Not found → inform the user the entry does not exist.
5. Found → ask for confirmation: "Remove **[question]** ([category])? Reply `yes` to confirm."
6. On confirmation: remove the row. If the category section becomes empty after removal, remove the entire section (heading + empty table).
7. Write updated content to `.smaqit/compendium.md`. Confirm removal.
8. No confirmation → abort; do not modify the file.

---

## Session-Finish Integration

When `smaqit.session-finish` runs, it executes the following compendium update step after the history file is written:

1. Scan the session transcript for user questions — identify questions that are project-specific, non-trivial, and were answered substantively by the agent.
2. Filter out: purely navigational questions ("what's next?", "can you recap?", "new session"), one-word commands, and meta-session phrases.
3. For each candidate question: check `.smaqit/compendium.md` for semantically similar existing entries.
4. If similar entry found: merge or update — rewrite the answer to incorporate new information, increment Sessions, update Last Updated.
5. If no similar entry found: create new entry, assign appropriate category, set Sessions to 1.
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
