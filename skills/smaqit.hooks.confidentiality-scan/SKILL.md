---
name: smaqit.hooks.confidentiality-scan
description: Scans staged git content for credential, PII, and financial-figure patterns before a commit, and explains how the automated pre-commit hook gets installed. Use when the user asks to scan staged changes for secrets/PII, check a commit for confidentiality issues, or install/troubleshoot the confidentiality git hook. Triggers: `confidentiality.scan`, `hooks.confidentiality-scan`.
metadata:
  version: "1.0.0"
---

# Confidentiality Scan

## When to use this skill

- User asks to scan staged changes for secrets, credentials, PII, or financial figures before committing
- A commit was blocked by the installed confidentiality pre-commit hook and the user wants an explanation or a manual re-check
- User asks how to install, reinstall, or troubleshoot the confidentiality git hook in a project
- A clone has not yet run `smaqit-extensions init`/`update`, but the user wants a one-off scan of currently staged content anyway

## Steps

### Manual invocation

1. Determine whether the project already has the hook installed:
   ```bash
   test -x .smaqit/hooks/pre-commit-confidentiality.sh && echo installed || echo not-installed
   ```
2. Run the scan against currently staged content (`git add` first if nothing is staged yet):
   - **If installed:** run the project's own copy, so any project-local pattern/exclude-list state is used —
     ```bash
     bash .smaqit/hooks/pre-commit-confidentiality.sh
     ```
   - **If not installed:** run this skill's bundled copy instead —
     ```bash
     bash [SMAQIT_SKILLS_DIR]/smaqit.hooks.confidentiality-scan/scripts/pre-commit-confidentiality.sh
     ```
     Note for this fallback path: there is no `.smaqit/hooks/confidentiality-scan-ignore` yet, so only the script's built-in default excludes (`.git/`, common build/dependency directories, lockfiles) apply — no project-specific exclusions.
3. A non-zero exit means the scan found one or more possible violations. Report each `file:line — possible CATEGORY` line from stderr to the user verbatim; never repeat the actual matched secret text.
4. A zero exit means the scan found nothing across currently staged files. Report this plainly — do not imply the whole repository was checked (the scan is delta-scoped: staged files only).

### Hook installation

The hook itself is installed by the `smaqit-extensions` installer, not by this skill — do not reimplement its logic here. It is opt-in via `--with-hooks`: a plain `init`/`update` never installs it, so an existing project never gets new commit-time behavior it didn't ask for. Point the user at:
```bash
smaqit-extensions init --with-hooks      # first-time project scaffolding, with the hook
smaqit-extensions update --with-hooks    # add the hook to (or refresh it in) an already-init'd project
```
Both force-overwrite `.smaqit/hooks/pre-commit-confidentiality.sh` (pattern/bug fixes always propagate on a later `--with-hooks` run) while leaving `.smaqit/hooks/confidentiality-scan-ignore` untouched after its first creation, and wire a namespaced managed block into `.git/hooks/pre-commit` — created fresh, replaced in place on reinstall, or appended after any pre-existing hook content from another tool. See `installer/main.go`'s `installConfidentialityHook`/`installConfidentialityGitHook` when reviewing or modifying the installer side; this skill only ever reads or manually runs the result.

### Reviewing a blocked commit

1. Read the blocked file(s) and line(s) from the hook's own stderr output — do not re-scan blindly.
2. For each reported hit, the user has three options: remove the sensitive content, add the path to `.smaqit/hooks/confidentiality-scan-ignore` after reviewing why it's a false positive, or bypass once with `git commit --no-verify` (the next scan still reports it — this is not an ack/suppress mechanism).
3. Never suggest weakening a detection pattern in `pre-commit-confidentiality.sh` to resolve a false positive — that file is force-overwritten on the next install, so a hand-edit there is silently lost. The exclude-list is the only durable, project-owned suppression path.

## Output

- A PASS (exit 0, silent) or a list of `file:line — possible CATEGORY` violations (exit non-zero) for currently staged content
- Category is one of `CREDENTIAL`, `FINANCIAL`, or `PII`
- No install-time output — hook installation is entirely owned by the `smaqit-extensions` installer

## Scope

- Staged content only (`git show :<path>`, filtered through `git diff --cached --diff-filter=ACM`) — never the working tree or unstaged changes, and never history/pre-existing violations elsewhere in the tree
- A coarse, cross-project, cross-language net — not a content-aware or CMS-integrated classifier. No ack/suppress mechanism beyond the exclude-list and `--no-verify`
- Binary files are skipped automatically (detected via `git diff --numstat`)
- Project-scoped only — there is no global install path for the git hook itself; each repository installs its own copy
- Does not modify `.git/hooks/pre-commit`, `.smaqit/hooks/pre-commit-confidentiality.sh`, or `.smaqit/hooks/confidentiality-scan-ignore` — installation and pattern changes are the installer's responsibility, not this skill's

## Examples

**Input:** User stages a file containing `AKIAABCDEFGHIJKLMNOP` and asks "will this pass the confidentiality check?"

**Output:**
```
pre-commit: confidentiality scan BLOCKED this commit:
  - config/deploy.env:3 — possible CREDENTIAL

Fix the above, exclude a reviewed false positive in .smaqit/hooks/confidentiality-scan-ignore, or bypass with 'git commit --no-verify' (the next scan still reports it).
```

**Input:** User asks "how do I turn this on for a repo that doesn't have it yet?"

**Output:** Run `smaqit-extensions init --with-hooks` from the repository root (or `update --with-hooks` if the project already ran a plain `init`). Confirm: "Confidentiality scan hook installed — it now runs automatically on every `git commit`. Add reviewed false positives to `.smaqit/hooks/confidentiality-scan-ignore`."

## Gotchas

- The bundled `scripts/pre-commit-confidentiality.sh` in this skill and `installer/hooks/pre-commit-confidentiality.sh` in the installer source are kept byte-for-byte in sync deliberately — the bundled copy exists only so manual invocation works in a clone that hasn't installed the hook yet. A pattern fix must be applied to both.
- `git add -p` (partial staging) can leave sensitive content in the working tree that never reaches the staged index this scan reads — it will not be caught.
- The detection regex set favors recall over precision by design (ported from `agentic-cms`'s `ac-classify` heuristic floor) — a real false positive is expected occasionally and is resolved via the exclude-list, never by asking for a narrower pattern.
- Patterns use POSIX ERE (`grep -E`, `[[:space:]]` not `\s`, no `\b`) and avoid bash 4+ features (associative arrays, `${var,,}`, `mapfile`) so the script runs unmodified on macOS's default bash 3.2 and BSD grep, not just Linux/GNU tooling.

## Completion Criteria

- [ ] Staged-file scan ran against the project's installed copy when present, or this skill's bundled copy otherwise
- [ ] Any violation reported as `file:line — possible CATEGORY`, never the matched secret text itself
- [ ] Hook-installation questions routed to `smaqit-extensions init`/`update`, not reimplemented here
- [ ] A blocked commit's resolution options (fix, exclude-list, `--no-verify`) explained without suggesting a pattern weakening

## Failure Handling

| Situation | Action |
|-----------|--------|
| Nothing staged | Report that there is nothing to scan; do not stage anything on the user's behalf |
| Neither installed nor bundled script found | Report the missing path and stop — do not hand-write a substitute scan |
| `git` unavailable | Report the missing dependency and stop |
| User asks to weaken/remove a detection pattern | Explain the exclude-list is the durable path instead; do not edit the detection script |
| User asks to install the hook | Point to `smaqit-extensions init`/`update`; do not hand-write `.git/hooks/pre-commit` |
