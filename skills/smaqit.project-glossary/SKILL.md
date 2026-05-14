---
name: smaqit.project-glossary
description: Manages a per-project glossary at `.smaqit/glossary.md`. Invoked when the user says `list glossary`, `fetch from glossary [term]`, `update glossary [term]`, or `remove from glossary [term]`. Lists all terms by category, retrieves a specific term, upserts a term (add or update), or removes a term after confirmation.
metadata:
  version: "1.2.0"
---

# Project Glossary

## Steps

### Glossary File Format

**Path:** `.smaqit/glossary.md`

Terms are grouped under `## [Category]` section headings (sorted alphabetically by category). Within each category, terms are sorted alphabetically by name. Each term entry is a bolded name (`**Term**`), followed by a blank line, the definition, and a `---` separator. There are no dates, no YAML frontmatter, and no per-entry metadata fields. See `assets/GLOSSARY_TEMPLATE.md` for the placeholder structure.

- Categories are sorted alphabetically; terms within each category are sorted alphabetically.
- Terms with no specified category go under `## General`.
- The file is the single source of truth — no other files are read or written by this skill.

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
3. Read `.smaqit/glossary.md`. Search for the term (case-insensitive, bolded term headings).
4. Found → present the term name, its category (derived from the section heading), and its definition.
5. Not found → state the exact term name and inform it is not in the glossary; suggest `update glossary [term]` to add it.

---

### Trigger: `update glossary [term]`

Upsert: add the term if absent; update it if already present.

1. Parse the term name from the user's message. If absent, ask: "Which term would you like to add or update?"
2. If no definition provided inline, ask for it.
3. If no category provided inline, ask for it. List existing categories from `.smaqit/glossary.md` as suggestions if the file exists. Default to `General` if none given.
4. If `.smaqit/glossary.md` does not exist: create it from the template (a `# Project Glossary` heading and a `## General` section) and add the new entry.
5. If `.smaqit/glossary.md` exists:
   - Term already present (case-insensitive): update its definition and category in place. If the category changed, move the entry to the correct section.
   - Term absent: insert it into the correct category section (alphabetically); create the section if absent. Category sections are kept in alphabetical order.
6. Write updated content to `.smaqit/glossary.md`.
7. Confirm: state whether the term was added or updated, and which category it was placed in.

---

### Trigger: `remove from glossary [term]`

1. Parse the term name from the user's message. If absent, ask: "Which term would you like to remove?"
2. Check if `.smaqit/glossary.md` exists. If not, respond: "No glossary found. Nothing to remove."
3. Read `.smaqit/glossary.md`. Search for the term (case-insensitive).
4. Not found → inform the user the term does not exist.
5. Found → ask for confirmation: "Remove **[term]** ([category]): [definition]? Reply `yes` to confirm."
6. On confirmation: remove the term entry (bolded heading, definition, and `---` separator). If the category section becomes empty after removal, remove the entire section (heading and any trailing separator).
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
- [ ] `fetch from glossary`: case-insensitive match on bolded term headings; handles missing file and missing term
- [ ] `update glossary`: upserts term; creates file if absent; creates category section if absent; maintains alphabetical order; no dates or metadata added
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
