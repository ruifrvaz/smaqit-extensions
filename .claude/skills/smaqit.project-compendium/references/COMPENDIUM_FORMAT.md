# Compendium Format Reference

This file defines the canonical entry format, file structure, and deduplication rules for `.smaqit/compendium.md`. Read this file before writing any entries to the compendium.

---

## File Structure

```markdown
# Project Compendium

## [Category Name]

**[Question text]**

[Answer as normal markdown prose]

---
```

See `assets/COMPENDIUM_TEMPLATE.md` for the full placeholder structure.

### Header

The file must start with a single `# Project Compendium` heading. There are no file-level stats lines, no YAML frontmatter, and no per-entry metadata.

### Category Sections

Each category is a `## Heading`. Categories are inferred by the agent from the nature of the question. Examples:

- `Release Workflow`
- `Task Management`
- `Installation`
- `Architecture`
- `Skill Usage`
- `General`

New categories are created as needed. The agent may reorganize categories when merging entries if the existing categorization no longer fits. A `## General` catch-all section is used when no specific category fits.

### Entry Format

Each entry consists of:

- A bolded question heading (`**Question text**`)
- A blank line
- The answer as normal markdown prose (may include multi-line text, code blocks, and bullet lists)
- A `---` separator after the answer

There are no tables, no per-entry dates, and no session counters.

---

## Deduplication Rules

Before creating a new entry, the agent must check for semantic duplicates. The agent reasons about meaning, not just keyword overlap.

### When to Merge

Merge two questions into one canonical entry when:

- They ask the same thing with different phrasing (e.g., "How do I release?" and "What's the release process?")
- One is a rephrasing or subset of the other
- They would produce the same answer

**Merge procedure:**
1. Choose the clearer, more canonical phrasing as the question heading
2. Write a combined answer that incorporates the best information from both
3. Place the merged entry in the most appropriate category

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
6. **State current, as-is facts — never historic narrative.** The compendium describes how the project *works today*: architecture, conventions, credentials, workflows, gotchas. It is not a changelog, incident log, or session diary.
   - Do not write entries as a timeline of what happened ("On 2026-07-16, X was destroyed...", "Following the incident...", "This was fixed by...").
   - Do not include dates unless the date itself is the answer to the question (e.g., "When does the license renew?").
   - Do not reference incident reports, session history files, or task IDs as the *reason* a fact is true — state the fact itself. A file reference is acceptable only as a pointer for further reading (per rule 2), not as narrative support ("see task 008 for why this changed").
   - If a session surfaces a noteworthy incident, decision, or timeline, that belongs in `.smaqit/history/` (session history) or `.smaqit/reports/` (incident/analysis reports) — not the compendium. The compendium may gain a *new or updated* entry describing the resulting current-state fact or convention, written as if it had always been true.
   - Test before writing: would this sentence still be accurate and sensible if read a year from now, with no memory of the session that produced it? If it depends on knowing "what happened," rewrite it as a standing fact or drop it.

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
- Questions whose only substantive answer is a narrative of a specific session's events (an incident, a debugging sequence, a one-off fix) with no lasting as-is fact to extract — route these to session history or an incident report instead

### Novelty Assessment

Before writing, compare each candidate against all existing entries:

1. Is the question semantically equivalent to an existing entry? → Merge/update
2. Is the question a refinement of an existing entry (new info added)? → Update answer
3. Is the question distinct and not yet in the compendium? → Create new entry
