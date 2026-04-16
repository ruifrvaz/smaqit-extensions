---
name: smaqit.project-init
description: Bootstrap a new smaqit project by generating a structured .github/copilot-instructions.md from a template. Use when the user asks to start a new smaqit project, init this project with smaqit, or set up smaqit for this project.
metadata:
  version: "0.1.0"
---

# Project Init

Bootstrap a new smaqit project by generating `.github/copilot-instructions.md` from the smaqit template.

## Steps

1. **Check for existing file**
   - Check whether `.github/copilot-instructions.md` already exists.
   - If it **does exist**, stop immediately and inform the user:
     > `.github/copilot-instructions.md` already exists. Aborting to avoid overwriting your project instructions. Delete or rename the existing file and run this skill again if you want to reinitialise.
   - Do **not** proceed past this step if the file exists.

2. **Read the template**
   - Read `.smaqit/templates/copilot-instructions.template.md` in full.
   - If the template file does not exist, stop and inform the user:
     > Template not found at `.smaqit/templates/copilot-instructions.template.md`. Run `smaqit-extensions init` to install the required scaffolding files.

3. **Gather project details from the user**
   - Ask the user for the following information (prompt for all at once):
     - **Project name** — what is this project called?
     - **Purpose / goal** — what problem does it solve or what is its main objective?
     - **Tech stack** — primary languages, frameworks, and infrastructure used.
     - **Key conventions** — coding style, branching strategy, naming rules, testing approach, or any other conventions the AI should follow.
     - **Any other domain context** — anything else the AI should know about the business domain, architecture, or constraints.
   - If the user cannot provide some details yet, use placeholder text (e.g., `[TODO: add purpose]`) for those fields.

4. **Populate the `# Project` section**
   - Take the template content from Step 2.
   - Replace the placeholders in the `# Project` section with the user-provided details gathered in Step 3.
   - Keep the `# Scaffolding` section exactly as it appears in the template — do **not** modify it.

5. **Write the output file**
   - Write the populated content to `.github/copilot-instructions.md`.
   - Confirm success to the user:
     > ✓ `.github/copilot-instructions.md` created successfully. Review and commit the file to include it in your project.

## Requirements

- **Never overwrite** an existing `.github/copilot-instructions.md` (Step 1 is a hard guard).
- The `# Scaffolding` section must be copied verbatim from the template — it is static and must not be altered.
- Placeholders are acceptable for any `# Project` fields the user cannot fill in immediately.
- Do **not** create any additional files beyond `.github/copilot-instructions.md`.
