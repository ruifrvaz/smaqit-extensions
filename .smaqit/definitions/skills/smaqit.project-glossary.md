# Skill Definition: smaqit.project-glossary

## Name

`smaqit.project-glossary`

## Description

Manages a per-project glossary at `.smaqit/glossary.md`. Use for: `list glossary`, `fetch from glossary`, `update glossary`, `remove from glossary`. Invoke when the user uses any of those trigger phrases to list all terms, retrieve a specific term, add or edit a term, or delete a term.

## Glossary File Format

**Path:** `.smaqit/glossary.md`

**Structure:** Markdown file with a `# Project Glossary` heading and one `## [Category]` section per category. Terms are bolded headings (`**Term**`) followed by a blank line, the definition, and a `---` separator. No tables, no dates, no per-entry metadata.

```markdown
# Project Glossary

## General

**Idempotent**

An operation that produces the same result whether applied once or many times.

---

## Engineering

**Upsert**

An operation that inserts a record if absent or updates it if already present.

---
```

- Categories are sorted alphabetically; terms within each category are sorted alphabetically.
- If a term belongs to no existing category, it is placed under a `## General` section.
- The file is the single source of truth — no other files are read or written by this skill.

## Steps

### Trigger: `list glossary`

1. Check if `.smaqit/glossary.md` exists.
   - If it does not exist, respond: "No glossary found at `.smaqit/glossary.md`. Use `update glossary` to add the first term."
   - Stop.
2. Read `.smaqit/glossary.md` in full.
3. Present all terms, grouped by category, in a readable format.
   - If the glossary is empty (file exists but has no entries), respond: "Glossary exists but contains no entries yet."

---

### Trigger: `fetch from glossary [term]`

1. Parse the term name from the user's message.
   - If no term is specified, ask: "Which term would you like to fetch?"
2. Check if `.smaqit/glossary.md` exists. If not, respond: "No glossary found. Use `update glossary` to create one."
3. Read `.smaqit/glossary.md`.
4. Search for the term (case-insensitive match on bolded term headings).
5. If found: present the term, its definition, and its category.
6. If not found: respond with the exact term name and inform the user it is not in the glossary. Suggest `update glossary [term]` to add it.

---

### Trigger: `update glossary [term]`

Implements **upsert semantics**: adds the term if absent; edits it if it already exists.

1. Parse the term name from the user's message.
   - If no term is specified, ask: "Which term would you like to add or update?"
2. Ask for the definition if not provided inline.
3. Ask for the category if not provided inline.
   - If `.smaqit/glossary.md` exists, list existing categories as suggestions.
   - If no category is given, default to `General`.
4. Check if `.smaqit/glossary.md` exists.
   - If it does **not** exist: create it with the standard header and the new entry.
   - If it **does** exist: read it, then:
     - If the term already exists (case-insensitive): update its definition and category in place.
     - If the term does not exist: append it to the correct category section (create the section if absent).
5. Write the updated content back to `.smaqit/glossary.md`.
6. Confirm: state whether the term was added or updated, and what category it was placed in.

---

### Trigger: `remove from glossary [term]`

1. Parse the term name from the user's message.
   - If no term is specified, ask: "Which term would you like to remove?"
2. Check if `.smaqit/glossary.md` exists. If not, respond: "No glossary found. Nothing to remove."
3. Read `.smaqit/glossary.md`.
4. Search for the term (case-insensitive).
5. If not found: inform the user the term does not exist.
6. If found: present the term and its definition. Ask for confirmation before deleting:
   - "Remove **[term]** ([category]): [definition]? Reply `yes` to confirm."
7. On confirmation: remove the term entry (bolded heading, definition, and `---` separator). If removing it leaves a category section empty, remove the entire section (heading and any trailing separator).
8. Write the updated content back to `.smaqit/glossary.md`.
9. Confirm removal.

---

## Output

- `.smaqit/glossary.md` — created or updated on `update glossary` and `remove from glossary` operations
- Formatted text responses for `list glossary` and `fetch from glossary`

## Scope

**In scope:**
- Managing `.smaqit/glossary.md` exclusively
- All four CRUD-style operations via the four trigger phrases
- Category grouping and alphabetical term ordering within categories

**Out of scope:**
- Syncing to or from `docs/glossary.md` or any other glossary file
- Auto-discovering terms from codebase or docs
- Bulk import/export
- Any session-start integration (that is handled by `smaqit.session-start`)

## Completion Criteria

- [ ] Skill file exists at `skills/smaqit.project-glossary/SKILL.md`
- [ ] Frontmatter includes correct `name`, `description` (with all four trigger phrases), and `metadata.version`
- [ ] `list glossary` trigger: reads and presents all terms grouped by category
- [ ] `fetch from glossary` trigger: finds and displays a single term by name (case-insensitive)
- [ ] `update glossary` trigger: upserts term (add if absent, edit if present); creates file if missing; no dates or metadata added
- [ ] `remove from glossary` trigger: requires confirmation before deletion; cleans up empty sections
- [ ] All operations handle missing `.smaqit/glossary.md` gracefully
- [ ] Glossary file format documented in the skill (section per category, bolded term headings)

## Failure Handling

| Situation | Action |
|-----------|--------|
| `.smaqit/glossary.md` does not exist on a read operation | Inform user; suggest using `update glossary` to create one |
| Term not found on fetch or remove | Inform user with exact term name; suggest `update glossary` to add it |
| No term name provided | Ask for clarification before proceeding |
| User does not confirm removal | Abort; do not modify the file |
| File write fails | Report the error and the intended change so user can apply manually |
