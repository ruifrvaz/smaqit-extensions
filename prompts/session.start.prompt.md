---
name: session.start
description: Start a new chat with full project context
---

# Session Start

Start a new chat with full project context. Execute these steps IN ORDER:

## Steps

1. **Read core project files from start to finish** (in parallel):
   - `README.md` (project root)
   - `framework/SMAQIT.md` (index + core principles)
   - `framework/LAYERS.md` (layer definitions)
   - `framework/PHASES.md` (phase workflows)
   - `framework/TEMPLATES.md` (template structure rules)
   - `framework/AGENTS.md` (agent behaviors)
   - `framework/ARTIFACTS.md` (artifact rules)
   - `framework/PROMPTS.md` (prompt architecture)

2. **Read the most recent history file from start to finish** from `docs/history/` (sorted by date descending)

3. **Read task planning file:** `docs/tasks/PLANNING.md` (NOT individual task files)

4. **Synthesize and present** a summary covering:
   - Current project state (from READMEs)
   - Recent changes and decisions (from history)
   - Open tasks sorted by priority
   - Suggested next steps

## Critical Requirements

**CRITICAL:** Read complete files without line limits. Do NOT truncate at any arbitrary limit.

**Note:** Only read individual task files (`docs/tasks/NNN_*.md`) when actively working on that specific task.
