---
name: smaqit.project-init
description: Bootstrap or refresh a smaqit project by inferentially synchronizing Codex, Claude Code, and GitHub Copilot project instructions around a canonical root AGENTS.md, then creating the base project directories (docs/, assets/, assets/raw/). Use when the user asks to start, initialize, reinitialize, or refresh a smaqit project.
metadata:
  version: "0.7.0"
---

# Project Init

Bootstrap or refresh project instructions without discarding instructions that already exist. Use model inference—not a deterministic merge script—to read the repository and all supported instruction sources, preserve their intent, and produce one coherent canonical document.

The synchronized topology is:

- `AGENTS.md` — canonical shared project instructions, read natively by Codex, GitHub Copilot (VS Code Copilot Chat, the coding agent, and Copilot CLI all read a root `AGENTS.md`), and Claude Code via the import below
- `CLAUDE.md` — `@AGENTS.md` import plus Claude-only instructions

There is no `.github/copilot-instructions.md` in this topology — GitHub Copilot reads root `AGENTS.md` directly, so no separate Copilot-specific file or symlink is created or maintained. A pre-existing `.github/copilot-instructions.md` from before this skill adopted that convention is legacy-migration input only (Step 8): its unique content is folded into `AGENTS.md` and the file is then removed.

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
   - Inspect `AGENTS.md` and `CLAUDE.md` when present; treat content reached through the `@AGENTS.md` import as one source, not independent duplicated guidance.
   - Also inspect `.github/copilot-instructions.md` when present, purely as legacy-migration input (see Step 8) — it is never a canonical output of this skill. Read it whether it is a regular file, a symlink (record its target and read the resolved content when available), or a broken symlink.
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

8. **Remove a legacy Copilot instructions file**
   - If `.github/copilot-instructions.md` does not exist, there is nothing to do — GitHub Copilot already reads root `AGENTS.md` directly.
   - If it exists (regular file, symlink, or broken symlink), first confirm every unique instruction it carried is now represented in `AGENTS.md` (from Step 3's migration input and Step 7's written content).
   - Once confirmed, delete `.github/copilot-instructions.md`. Leaving it in place would give Copilot two divergent instruction sources, since Copilot reads both `AGENTS.md` and `.github/copilot-instructions.md` when both exist.
   - If confirmation fails (unique content cannot be verified as represented), do not delete the file — report the failure and the specific content that could not be safely migrated.

9. **Scaffold base project directories**
   - Create `docs/`, `assets/`, and `assets/raw/` if they do not already exist.
   - Never delete or modify their existing contents.
   - Report which directories were created and which already existed, then tell the user: "Place raw project assets in `assets/raw/` before continuing."

10. **Report the synchronization result**
    - Report files created, rewritten, or preserved; whether a legacy `.github/copilot-instructions.md` was migrated and removed; project fields inferred or left as placeholders; and any platform-specific sections retained.
    - Mention that Claude Code has known upstream issues resolving imports from an ancestor `CLAUDE.md` when launched in some repository subdirectories. Recommend launching Claude Code from the project root if the imported instructions are not loaded.

## Requirements

- File existence is migration input, never an overwrite-abort condition by itself.
- Read all existing instruction sources before modifying any of them.
- Semantic merging must be performed through model inference, not delegated to a deterministic script.
- Never silently discard, weaken, or invent project instructions.
- Never leave a legacy `.github/copilot-instructions.md` in place once its unique content is represented in `AGENTS.md` — remove it so Copilot has exactly one instruction source, never two divergent ones.
- Do not delete a populated Copilot path until its distinct content is confirmed represented in `AGENTS.md`.
- Preserve exactly one `@AGENTS.md` import and one smaqit `# Scaffolding` section.
- A repeat run with unchanged inputs must avoid duplicate content, meaningful semantic churn, and must never recreate `.github/copilot-instructions.md`.
- Directory scaffolding is idempotent and must never alter existing directory contents.
- Do not create backup, temporary, or platform-copy instruction files in the project.
