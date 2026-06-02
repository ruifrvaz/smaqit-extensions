# Assessment Template — smaqit.parity-assess

**Version:** 2.0.0  
**Read before:** Phase 4 of every parity assessment.

Fill in every section. Replace all `<placeholders>` with content discovered in Phases 0–1. Mark genuinely unknown values with `[?]` and a brief inline note.

**Project A** = the current project (host).  
**Project B** = the target system being assessed (`<name>`).

---

```markdown
# <Name> Parity Assessment

Source: <URL>  
Studied: <YYYY-MM-DD> · <commit SHA or version>

## What `<name>` is

[2–4 sentences. Cover: purpose, primary use-case, language/runtime, and 2–3 key differentiating features. Factual — do not compare to Project A yet.]

Key properties:
- **<Property 1>** — <value>
- **<Property 2>** — <value>
- **<Property 3>** — <value>

---

## Structural Mapping

[Pair each discovered concept in Project B with its counterpart in Project A.  
Mapping quality: **1:1** (direct equivalent) · **partial** (similar but different scope) · **absent** (Project A has no equivalent) · **a-only** (Project A has this; Project B does not).

Derive rows from the features discovered in Phases 0 and 1 — do not copy rows from this template verbatim. Add or remove rows as needed.]

| Concept | Project B implementation | Project A equivalent | Mapping quality |
|---------|------------------------|--------------------|-----------------|
| [Core abstraction / carrier] | `<type or class>` | `<type or class>` | <quality> |
| [Primary processing unit] | `<function / component>` | `<function / component>` | <quality> |
| [Extension / plugin model] | `<API / interface>` | `<API / interface>` | <quality> |
| [State / persistence model] | `<format / class>` | `<format / class or "none">` | <quality> |
| [Configuration / registration] | `<mechanism>` | `<mechanism>` | <quality> |
| [Feature unique to B] | `<description>` | None | absent |
| [Feature unique to A] | None | `<description>` | a-only |

---

## Relationship Options

[Enumerate the realistic options for how Project A could relate to Project B. Include only options that are genuinely applicable. Common options are listed below — adapt, add, or remove as needed.]

### Option A — Direct integration (subprocess / SDK / RPC)

[Describe: how Project B would be embedded or called from Project A. What the interface looks like. What translation is needed.]

**Pros:**
- <pro>

**Cons:**
- <con>

**Verdict:** [1–2 sentences. State viability and time horizon.]

---

### Option B — Feature parity (implement equivalent capabilities natively)

[Describe: which Project B features map to which Project A tasks or components. Reference specific source files as design specs.]

**Pros:**
- <pro>

**Cons:**
- <con>

**Verdict:** [1–2 sentences.]

---

### Option C — Use as design reference only

[Describe: treat Project B's codebase as a specification; implement natively without a runtime dependency.]

**Verdict:** [1–2 sentences.]

---

### Option D — Adopt / replace *(include only if applicable)*

[Describe: replace part of Project A with Project B, or adopt Project B as the primary implementation.]

**Verdict:** [1–2 sentences.]

---

## Recommendation

**Option [letter] — [option name]**

[1 sentence stating the recommendation.]

Rationale:

1. [Architectural fit — why this option aligns with Project A's structure]
2. [Delivery path — what this option enables or unblocks]
3. [Risk or constraint — security, deployment, maintenance boundary]
4. [Project A advantage — what Project A has that justifies not simply adopting B]
5. [Optional: maintenance cost or long-term trajectory]

---

## Parity Roadmap

[Ordered by delivery priority. Include only features worth closing. Skip cosmetic or power-user-only differences.]

| Priority | Feature | Project B reference file | Project A task / component | Status | Benefit |
|----------|---------|------------------------|--------------------------|--------|---------|
| 1 | <feature> | `<path/to/file>` | <task or component> | <status> | <benefit> |
| 2 | <feature> | `<path/to/file>` | <task or component> | <status> | <benefit> |
| 3 | <feature> | `<path/to/file>` | unplanned | — | <benefit> |

---

## Project A Advantages

[Capabilities Project A has that Project B lacks. These are the counter-arguments to simple adoption. Include only real, demonstrable advantages — not aspirational ones.]

| Project A capability | Project B equivalent |
|---------------------|---------------------|
| <capability> | None / <equivalent> |
| <capability> | None / <equivalent> |
```

---

## Writing Rules

1. **Structural mapping rows come from discovery, not from this template.** Read the systems first; then populate the table with what you found.
2. **Include only the relationship options that are genuinely applicable.** Do not add option D if it is not realistic.
3. **The recommendation must be unambiguous.** Do not say "it depends" without immediately resolving the dependency.
4. **The roadmap is ordered by delivery priority**, not by feature completeness or importance in Project B.
5. **Project A advantages are mandatory.** If Project A has no meaningful advantages over Project B, state that explicitly — it changes the recommendation.
6. **Mark genuinely unknown fields with `[?]`** and a note. Do not guess.
