---
name: smaqit.project-init
description: Bootstrap or refresh a smaqit project by inferentially synchronizing Codex, Claude Code, and GitHub Copilot project instructions around a canonical root AGENTS.md, then creating the base project directories (docs/, assets/, assets/raw/). Use when the user asks to start, initialize, reinitialize, or refresh a smaqit project.
metadata:
  version: "0.6.0"
---

# Project Init

Bootstrap or refresh project instructions without discarding instructions that already exist. Use model inference—not a deterministic merge script—to read the repository and all supported instruction sources, preserve their intent, and produce one coherent canonical document.

The synchronized topology is:

- `AGENTS.md` — canonical shared project instructions
- `CLAUDE.md` — `@AGENTS.md` import plus Claude-only instructions
- `.github/copilot-instructions.md` — relative symlink to `../AGENTS.md`

## Steps

1. **Resolve the project root**
   - Work at the enclosing Git worktree root when one exists.
   - Outside Git, use the nearest ancestor containing `.smaqit`; otherwise use the current directory.
   - Resolve all paths below relative to that project root.

2. **Read the template**
   - Read [references/AGENTS.template.md](references/AGENTS.template.md) in full. This is a skill-bundled reference, installed alongside the skill itself — it is not project-scaffolded and never depends on `.smaqit/` state.
   - If it does not exist, stop and inform the user:
     > Template not found at `references/AGENTS.template.md`. The smaqit-extensions skill install looks incomplete or corrupted — run `smaqit-extensions update` to refresh it, or reinstall via `curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | bash`.

3. **Read every existing instruction source before writing**
   - Inspect `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` when present.
   - Determine whether each path is a regular file or symlink. For a symlink, record its target and read its resolved content when available.
   - Treat content reached through a symlink or an `@AGENTS.md` import as one source, not as independent duplicated guidance.
   - Preserve the content of a pre-existing Copilot regular file, different symlink target, or broken symlink as migration input before replacing that path.
   - Do not stop merely because one or more instruction files already exist.

4. **Assess the repository for project evidence**
   - Read whichever relevant sources exist, including `README.md`, `CONTRIBUTING.md`, build and dependency manifests, `Makefile`, lint/test configuration, and documentation indexes.
   - Ignore smaqit scaffolding paths listed by the template when inferring business context, architecture, domain logic, or project conventions.
   - Derive project name, purpose, technology stack, conventions, and domain context only from clear repository evidence.
   - Leave the template's placeholder text unchanged when evidence is missing or ambiguous. Never invent project facts.

5. **Infer one coherent instruction model**
   - Perform this step through semantic inference. Do not generate or run a Go, Python, shell, regex, AST, or other deterministic program to merge instruction prose.
   - Preserve every explicit project rule materially intact, including unusual prose or headings. Reorganize only when it improves coherence without weakening meaning.
   - Semantically deduplicate equivalent guidance while retaining the clearest or most specific form.
   - Existing explicit project instructions take precedence over weaker repository inference.
   - The template is authoritative only for the smaqit-owned `# Scaffolding` section; include that section exactly once and keep its content verbatim.
   - Merge shared guidance and evidence-grounded `# Project` details into the canonical model.
   - Keep genuinely Claude-only instructions for the `CLAUDE.md` wrapper.
   - Put Codex-only or Copilot-only instructions in clearly labelled platform-specific sections of `AGENTS.md`, stating which tool each section applies to. The other tools must be told to ignore sections not addressed to them.
   - If explicit existing rules are irreconcilably contradictory, show the precise conflict and ask the user which rule should win. Do not write any instruction file until the conflict is resolved.

6. **Prepare and validate the complete outputs before mutation**
   - Prepare the full canonical `AGENTS.md` content and the full `CLAUDE.md` wrapper content before writing either file.
   - `CLAUDE.md` must begin with `@AGENTS.md`, followed only by genuinely Claude-specific instructions. Do not repeat shared content below the import.
   - Confirm that all unique instructions read in Step 3 are represented, required template content appears exactly once, inferred statements are grounded, and imports or sections are not duplicated.

7. **Write the canonical and Claude files**
   - Write `AGENTS.md` first.
   - Read it back and confirm it contains the prepared canonical content before proceeding.
   - Write `CLAUDE.md`, then verify its first non-empty line is exactly `@AGENTS.md` and its remaining content is Claude-specific.

8. **Migrate the Copilot path to the canonical symlink**
   - Ensure `.github/` exists.
   - If `.github/copilot-instructions.md` is already a symlink whose target is exactly `../AGENTS.md`, leave it unchanged.
   - Otherwise, replace it only after its prior unique content has been verified in `AGENTS.md`.
   - Create `.github/copilot-instructions.md` as a relative symlink to `../AGENTS.md` and verify both the recorded target and resolved content.
   - Retain the prior Copilot content in context until verification succeeds. If replacement or verification fails, restore the prior regular file or symlink when possible, report the failure, and do not create a copied fallback that could drift from `AGENTS.md`.

9. **Scaffold base project directories**
   - Create `docs/`, `assets/`, and `assets/raw/` if they do not already exist.
   - Never delete or modify their existing contents.
   - Report which directories were created and which already existed, then tell the user: "Place raw project assets in `assets/raw/` before continuing."

10. **Report the synchronization result**
    - Report files created, rewritten, preserved, or migrated; the Copilot symlink target; project fields inferred or left as placeholders; and any platform-specific sections retained.
    - Mention that Claude Code has known upstream issues resolving imports from an ancestor `CLAUDE.md` when launched in some repository subdirectories. Recommend launching Claude Code from the project root if the imported instructions are not loaded.

## Requirements

- File existence is migration input, never an overwrite-abort condition by itself.
- Read all existing instruction sources before modifying any of them.
- Semantic merging must be performed through model inference, not delegated to a deterministic script.
- Never silently discard, weaken, or invent project instructions.
- Never write through the Copilot symlink as though it were an independent file; update canonical `AGENTS.md` instead.
- Do not replace a populated Copilot path until its distinct content is represented in `AGENTS.md`.
- Preserve exactly one `@AGENTS.md` import and one smaqit `# Scaffolding` section.
- A repeat run with unchanged inputs must preserve the correct symlink and avoid duplicate content or meaningful semantic churn.
- Directory scaffolding is idempotent and must never alter existing directory contents.
- Do not create backup, temporary, or platform-copy instruction files in the project.
