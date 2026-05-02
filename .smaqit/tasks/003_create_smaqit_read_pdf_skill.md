# Create smaqit.read-pdf Skill

**Status:** Not Started  
**Created:** 2026-05-02

## Description

Create a new `smaqit.read-pdf` skill for the smaqit-extensions repository. The skill enables agents to extract text from PDF files using `pdftotext`, then continue with the caller's original goal using the extracted content.

This skill is a mid-request utility: when a user asks an agent to review, summarize, or analyze a PDF, the agent activates the skill, extracts the text to a sidecar file, reads it, and resumes the original task.

**Trigger condition:** User references a `.pdf` file path and asks for any content-based action (review, summarize, analyze, benchmark extraction, etc.).

## Directory Structure

Per the [agentskills.io specification](https://agentskills.io/specification):

```
skills/smaqit.read-pdf/
├── SKILL.md
└── scripts/
    └── extract.sh
```

No `references/` or `assets/` directories needed — instructions fit in `SKILL.md`.

## Steps

1. **Create `skills/smaqit.read-pdf/SKILL.md`** with:
   - `name: smaqit.read-pdf`
   - `description`: explains what the skill does and when to invoke it (PDF file referenced, content-based action requested)
   - `compatibility`: `Requires poppler-utils (pdftotext). Install with: sudo apt install poppler-utils`
   - `metadata.version: "0.1.0"`
   - Body instructions (see Acceptance Criteria for required behavior)

2. **Create `skills/smaqit.read-pdf/scripts/extract.sh`** — self-contained pdftotext wrapper:
   - Accept PDF path as `$1`
   - Check `command -v pdftotext`; exit 1 with clear install instruction if not found
   - Run `pdftotext -layout "$1" "${1%.pdf}.extracted.txt"`
   - Print sidecar path to stdout on success
   - Handle edge cases: file not found, unreadable PDF, empty output

3. **Make `extract.sh` executable** — `chmod +x skills/smaqit.read-pdf/scripts/extract.sh`

4. **Write SKILL.md body** with agent instructions:
   - Step 1: Run `scripts/extract.sh <pdf-path>` via terminal
   - Step 2: Read the sidecar file path printed to stdout
   - Step 3: Read sidecar content using `read_file`
   - Step 4: Continue with the caller's original goal using the extracted text
   - Include: sidecar naming convention, install instructions if tool missing

5. **Run `make sync`** from the smaqit-extensions root to populate `.github/skills/smaqit.read-pdf/`

6. **Verify sync** — confirm `.github/skills/smaqit.read-pdf/SKILL.md` and `.github/skills/smaqit.read-pdf/scripts/extract.sh` exist

7. **Update PLANNING.md** — mark task 003 as Completed

## Acceptance Criteria

- [ ] `skills/smaqit.read-pdf/SKILL.md` exists with correct frontmatter: `name`, `description`, `compatibility`, `metadata.version: "0.1.0"`
- [ ] `skills/smaqit.read-pdf/scripts/extract.sh` exists and is executable (`chmod +x`)
- [ ] `extract.sh` checks for `pdftotext`; prints `sudo apt install poppler-utils` and exits 1 if missing
- [ ] `extract.sh` writes sidecar as `<pdf-basename>.extracted.txt` next to the source PDF
- [ ] `extract.sh` prints the sidecar path to stdout on success
- [ ] SKILL.md body instructs the agent to run the script, read the sidecar, then continue with the caller's original goal
- [ ] `make sync` run; `.github/skills/smaqit.read-pdf/` is populated and matches source
- [ ] `skills-ref validate ./skills/smaqit.read-pdf` passes (if `skills-ref` is available)

## Notes

**Spec deviation:** The agentskills.io spec requires `name` to use only `a-z` and hyphens. All existing smaqit skills use dot notation (`smaqit.session-start`, etc.). Follow the existing project convention — use `smaqit.read-pdf` as the name.

**Sidecar policy:** Written next to the source PDF by default (`<pdf-basename>.extracted.txt`). No `/tmp/` unless the user specifies otherwise.

**Scope:** Single file only. Multi-PDF support is out of scope for v0.1.0.

**`poppler-utils` status:** Not installed on the development WSL at time of task creation. Running `sudo apt install poppler-utils` is a prerequisite before the skill can be tested end-to-end.

**Context for first-session pickup:** The immediate use case that prompted this task was reading `assets/docs/nvidia-dgx-spark-review-pros-cons-performance-benchmarks.pdf` in the daisy-tribe workspace, where the agent could not access the PDF content natively. This skill unblocks that and any future PDF-based workflows.
