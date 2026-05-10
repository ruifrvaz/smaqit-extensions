# Compendium Format Reference

This file defines the canonical entry format, file structure, and deduplication rules for `.smaqit/compendium.md`. Read this file before writing any entries to the compendium.

---

## File Structure

```markdown
# Project Compendium

Last updated: YYYY-MM-DD | Total entries: N

## [Category Name]

| Question | Answer | Last Updated | Sessions |
|----------|--------|--------------|----------|
| How do I release a new version? | Run `smaqit.release.local` agent... | 2026-05-09 | 3 |
```

### Header

The file must start with:

```
# Project Compendium

Last updated: YYYY-MM-DD | Total entries: N
```

- `Last updated` — date of the most recent write in `YYYY-MM-DD` format
- `Total entries` — count of all Q&A rows across all categories

### Category Sections

Each category is a `## Heading`. Categories are inferred by the agent from the nature of the question. Examples:

- `Release Workflow`
- `Task Management`
- `Installation`
- `Architecture`
- `Skill Usage`
- `General`

New categories are created as needed. The agent may reorganize categories when merging entries if the existing categorization no longer fits. A `## General` catch-all section is used when no specific category fits.

### Entry Columns

| Column | Description |
|--------|-------------|
| `Question` | The canonical question text — synthesized clean phrasing, not raw session dialogue |
| `Answer` | A self-contained, reusable answer — may include code snippets, file paths, and skill names; no external URLs |
| `Last Updated` | `YYYY-MM-DD` of the last time this entry was written or merged |
| `Sessions` | Integer count of sessions that have referenced or updated this entry |

---

## Multi-Line Answers

Markdown table cells do not support raw newlines. For answers that require formatting:

- Use `<br>` for line breaks within a cell
- Use inline backticks for code references (e.g., `` `make sync` ``)
- Keep answers as concise as possible while remaining self-contained

**Example:**

```
| How do I sync changes to .github/? | Edit source files in `agents/` or `skills/`, then run `make sync`.<br>Example: `make sync` copies files to `.github/` for Copilot to use. | 2026-05-09 | 2 |
```

---

## Deduplication Rules

Before creating a new entry, the agent must check for semantic duplicates. The agent reasons about meaning, not just keyword overlap.

### When to Merge

Merge two questions into one canonical entry when:

- They ask the same thing with different phrasing (e.g., "How do I release?" and "What's the release process?")
- One is a rephrasing or subset of the other
- They would produce the same answer

**Merge procedure:**
1. Choose the clearer, more canonical phrasing as the Question text
2. Write a combined Answer that incorporates the best information from both
3. Set Last Updated to today
4. Set Sessions to the sum of both entries' Sessions counts
5. Place the merged entry in the most appropriate category

### When to Cross-Reference

Add a note in the Answer (not a separate entry) when two questions are related but distinct:

- They ask related but different things (e.g., "How do I install?" vs. "How do I update?")
- They would produce different answers, but the reader of one would benefit from knowing the other exists

**Cross-reference format:** Append to the Answer: `See also: [related question text]`

### When to Create New Entry

Create a new entry when:

- No semantically similar question exists in the compendium
- The question is clearly distinct from all existing entries

---

## Writing Rules

1. **Answers must be self-contained** — a reader should understand the answer without needing the session context that produced it
2. **No external URLs** — reference file paths or skill names instead (e.g., `skills/smaqit.release-git-pr/SKILL.md` not `https://...`)
3. **Synthesize, don't copy** — rewrite Q&A pairs into clean, reusable knowledge; do not copy raw session dialogue verbatim
4. **Err on inclusion for novel questions** — if uncertain whether a question is notable enough, include it
5. **Err on merging for similar questions** — if uncertain whether two questions are the same, merge them
6. **Update the header** after every write: recalculate `Last updated` and `Total entries`

---

## Session-Finish Scanning Rules

When scanning a session transcript for compendium candidates:

### Include

- Project-specific questions with substantive answers (e.g., "How does the sync work?", "What format does PLANNING.md use?")
- How-to questions that the agent answered with concrete steps
- Architecture or design questions where a decision was explained
- Questions about workflows, tools, or conventions used in this project

### Exclude

- Purely navigational inputs: "what's next?", "continue", "proceed", "go ahead"
- Meta-session commands: "new session", "session start", "session finish", "can you recap?"
- One-word or one-phrase inputs with no question structure
- Questions whose answers are entirely generic (not project-specific)
- Questions already fully covered by an existing compendium entry with no new information

### Novelty Assessment

Before writing, compare each candidate against all existing entries:

1. Is the question semantically equivalent to an existing entry? → Merge/update
2. Is the question a refinement of an existing entry (new info added)? → Update answer, increment Sessions
3. Is the question distinct and not yet in the compendium? → Create new entry
