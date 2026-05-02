# Skill Definition: smaqit.read-pdf

## Name

`smaqit.utilities.read-pdf`

## Description

Extracts text from a PDF file using `pdftotext`, writes the content to a sidecar `.extracted.txt` file next to the source PDF, reads the extracted text, and continues with the caller's original goal. Use when the user references a `.pdf` file path and requests any content-based action: review, summarize, analyze, benchmark extraction, or similar.

## Invocation Triggers

- User references a `.pdf` file and asks for content-based action
- Agent detects a `.pdf` path in the conversation and the task requires reading its content

## Steps

1. **Run `scripts/extract.sh <pdf-path>`** via terminal
   - The script checks for `pdftotext`; if not found, it prints `sudo apt install poppler-utils` and exits 1
   - On success, it writes `<pdf-basename>.extracted.txt` next to the source PDF and prints the sidecar path to stdout
   - The agent reads the printed sidecar path from terminal output

2. **Read the sidecar file** using `read_file` on the path from step 1

3. **Continue with the caller's original goal** using the extracted text
   - Do not stop after extraction — extraction is a pipeline step, not the final output
   - Apply the user's intent (review, summarize, analyze, etc.) to the extracted content

## Output

- `<pdf-basename>.extracted.txt` — plain text sidecar written next to the source PDF
- Continuation of the caller's original task using the extracted content

## Scope

- Single file only — multi-PDF support is out of scope for v0.1.0
- Sidecar is always written next to the source PDF (no `/tmp/` unless user specifies)
- The skill does not post-process or format the extracted text itself — it surfaces it for the caller's goal
- Does not create agents, framework files, or templates

## Completion Criteria

- [ ] `skills/smaqit.read-pdf/SKILL.md` exists with correct frontmatter: `name`, `description`, `compatibility`, `metadata.version: "0.1.0"`
- [ ] `skills/smaqit.read-pdf/scripts/extract.sh` exists and is executable (`chmod +x`)
- [ ] `extract.sh` checks for `pdftotext`; prints `sudo apt install poppler-utils` and exits 1 if missing
- [ ] `extract.sh` writes sidecar as `<pdf-basename>.extracted.txt` next to the source PDF
- [ ] `extract.sh` prints the sidecar path to stdout on success
- [ ] SKILL.md body instructs the agent to run the script, read the sidecar path from stdout, read the sidecar with `read_file`, then continue with the caller's original goal
- [ ] `make sync` run; `.github/skills/smaqit.read-pdf/` is populated and matches source

## Failure Handling

| Situation | Action |
|-----------|--------|
| `pdftotext` not installed | Print `sudo apt install poppler-utils` and exit 1; agent surfaces install instruction to user |
| PDF file not found | `extract.sh` exits 1 with clear error message including the attempted path |
| PDF is unreadable or corrupted | `extract.sh` exits 1; agent reports failure to user |
| Sidecar output is empty | `extract.sh` exits 1 with message "Extracted text is empty — PDF may be image-only or protected" |
| Sidecar file already exists | Overwrite silently (idempotent re-runs) |

## Spec Notes

- **Naming convention:** agentskills.io spec requires `a-z` and hyphens only. All existing smaqit skills use dot notation (`smaqit.session-start`, etc.). Follow the project convention: use `smaqit.read-pdf`.
- **`compatibility` field:** Must declare `poppler-utils` requirement per agentskills.io spec.
- **`allowed-tools`:** `Bash run_in_terminal read_file` — the skill uses terminal and file reading only.
- **Script language:** Bash (`scripts/extract.sh`) — consistent with project conventions (`set -euo pipefail`, `[CHECK]`/`[OK]`/`[ERROR]` echo prefixes).
