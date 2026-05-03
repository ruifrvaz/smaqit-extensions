---
name: smaqit.utils.read-pdf
description: Extracts text from a PDF file, writes a sidecar .extracted.txt file, reads it, and continues with the caller's original goal. Use when the user references a .pdf file path and requests any content-based action: review, summarize, analyze, benchmark extraction, or similar.
compatibility: Requires poppler-utils (pdftotext). Install with: sudo apt install poppler-utils
allowed-tools: Bash run_in_terminal read_file
metadata:
  version: "0.1.0"
---

# Read PDF

## When to use this skill

- User references a `.pdf` file path and requests a content-based action (review, summarize, analyze, benchmark extraction, or similar)
- Agent detects a `.pdf` path in the conversation and the task requires reading its content

## Steps

### Step 1: Run extraction script

Run `scripts/extract.sh <pdf-path>` via terminal:

```bash
bash skills/smaqit.read-pdf/scripts/extract.sh "<pdf-path>"
```

- If `pdftotext` is not installed, the script prints `sudo apt install poppler-utils` and exits 1. Surface this instruction to the user and stop.
- If the PDF is not found, the script exits 1 with the attempted path. Report the error to the user and stop.
- If the extracted text is empty, the script exits 1 with the message `Extracted text is empty — PDF may be image-only or protected`. Report this to the user and stop.
- On success, the script prints the sidecar path to stdout (e.g., `/path/to/file.extracted.txt`).

### Step 2: Read the sidecar path from terminal output

Read the last line of stdout from Step 1. That line is the absolute or relative path to the sidecar file.

### Step 3: Read the sidecar file

Use `read_file` on the path captured in Step 2. Read the full file without truncation.

### Step 4: Continue with the caller's original goal

Apply the user's intent (review, summarize, analyze, etc.) to the extracted content. Do not stop after extraction — extraction is a pipeline step, not the final output.

## Output

- `<pdf-basename>.extracted.txt` — plain text sidecar written next to the source PDF
- Continuation of the caller's original task using the extracted content

## Scope

- Single file only — multi-PDF support is out of scope for v0.1.0
- Sidecar is always written next to the source PDF (no `/tmp/` unless user specifies)
- The skill does not post-process or format the extracted text — it surfaces it for the caller's goal
- Does not create agents, framework files, or templates

## Completion Criteria

- [ ] `extract.sh` ran without error
- [ ] Sidecar `.extracted.txt` file exists next to the source PDF
- [ ] Sidecar file content was read in full
- [ ] Caller's original goal was addressed using the extracted content

## Failure Handling

| Situation | Action |
|-----------|--------|
| `pdftotext` not installed | Script prints `sudo apt install poppler-utils` and exits 1; surface install instruction to user and stop |
| PDF file not found | Script exits 1 with the attempted path; report error to user and stop |
| PDF is unreadable or corrupted | Script exits 1; report failure to user and stop |
| Sidecar output is empty | Script exits 1 with message "Extracted text is empty — PDF may be image-only or protected"; report to user and stop |
| Sidecar file already exists | Overwrite silently (idempotent re-runs) |
