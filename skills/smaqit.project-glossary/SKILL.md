---
name: smaqit.project-glossary
description: Manages a per-project glossary at `.smaqit/glossary.md`. Invoked when the user says `list glossary`, `fetch from glossary [term]`, `update glossary [term]`, or `remove from glossary [term]`. Lists all terms by category, retrieves a specific term, upserts a term (add or update), or removes a term after confirmation.
metadata:
  version: "1.0.0"
---

# Project Glossary

## Purpose

Manages `.smaqit/glossary.md` as a per-project term reference. Supports four operations triggered by explicit phrases in the user's message: listing all terms, fetching a specific term, upserting a term (add if absent, update if present), and removing a term with confirmation. The glossary file is the sole artifact this skill reads or writes.

## Steps

### Glossary File Format

**Path:** `.smaqit/glossary.md`

Terms are stored in Markdown tables with three columns (`Term`, `Definition`, `Category`), grouped into sections by category. Each category is a `## Heading`. Terms within a category are sorted alphabetically. Terms with no matching category go under `## General`.

    # Project Glossary

    ## [Category Name]

    | Term | Definition | Category |
    |------|-----------|----------|
    | example | What the term means | [Category Name] |

---

### Trigger: `list glossary`

1. Check if `.smaqit/glossary.md` exists.
   - Does not exist → respond: "No glossary found at `.smaqit/glossary.md`. Use `update glossary` to add the first term." Stop.
2. Read `.smaqit/glossary.md`.
3. Present all terms grouped by category.
   - File exists but contains no entries → respond: "Glossary exists but contains no entries yet."

---

### Trigger: `fetch from glossary [term]`

1. Parse the term name from the user's message. If absent, ask: "Which term would you like to fetch?"
2. Check if `.smaqit/glossary.md` exists. If not, respond: "No glossary found. Use `update glossary` to create one."
3. Read `.smaqit/glossary.md`. Search for the term (case-insensitive, Term column).
4. Found → present term, definition, and category.
5. Not found → state the exact term name and inform it is not in the glossary; suggest `update glossary [term]` to add it.

---

### Trigger: `update glossary [term]`

Upsert: add the term if absent; update it if already present.

1. Parse the term name from the user's message. If absent, ask: "Which term would you like to add or update?"
2. If no definition provided inline, ask for it.
3. If no category provided inline, ask for it. List existing categories from `.smaqit/glossary.md` as suggestions if the file exists. Default to `General` if none given.
4. If `.smaqit/glossary.md` does not exist: create it with the standard header and the new entry.
5. If `.smaqit/glossary.md` exists:
   - Term already present (case-insensitive): update its definition and category in place.
   - Term absent: append it to the correct category section; create the section if absent. Maintain alphabetical order within the category.
6. Write updated content to `.smaqit/glossary.md`.
7. Confirm: state whether the term was added or updated, and which category it was placed in.

---

### Trigger: `remove from glossary [term]`

1. Parse the term name from the user's message. If absent, ask: "Which term would you like to remove?"
2. Check if `.smaqit/glossary.md` exists. If not, respond: "No glossary found. Nothing to remove."
3. Read `.smaqit/glossary.md`. Search for the term (case-insensitive).
4. Not found → inform the user the term does not exist.
5. Found → ask for confirmation: "Remove **[term]** ([category]): [definition]? Reply `yes` to confirm."
6. On confirmation: remove the row. If the category section becomes empty after removal, remove the entire section (heading + empty table).
7. Write updated content to `.smaqit/glossary.md`. Confirm removal.
8. No confirmation → abort; do not modify the file.

---

## Output

- `.smaqit/glossary.md` — created or updated by `update glossary`; updated by `remove from glossary`
- Formatted text responses for `list glossary` and `fetch from glossary`

## Scope

**In scope:**
- All four operations on `.smaqit/glossary.md`
- Category grouping and alphabetical term ordering within categories

**Out of scope:**
- Syncing to or from any other glossary file (e.g., `docs/glossary.md`)
- Auto-discovering terms from codebase or documentation
- Bulk import or export
- Session-start integration (handled by `smaqit.session-start`)

## Completion

- [ ] Frontmatter includes `name`, `description` (with all four trigger phrases), and `metadata.version`
- [ ] `list glossary`: reads and presents all terms by category; handles missing file
- [ ] `fetch from glossary`: case-insensitive match; handles missing file and missing term
- [ ] `update glossary`: upserts term; creates file if absent; creates category section if absent; maintains alphabetical order
- [ ] `remove from glossary`: requires confirmation before deletion; removes empty category sections after deletion
- [ ] All operations handle missing `.smaqit/glossary.md` gracefully

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| `.smaqit/glossary.md` does not exist on a read operation | Inform user; suggest `update glossary` to create it |
| Term not found on fetch or remove | State the exact term name; suggest `update glossary [term]` to add it |
| User does not confirm removal | Abort; do not modify the file |
| File write fails | Report the error and the intended change so the user can apply it manually |
