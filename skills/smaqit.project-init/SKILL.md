---
name: smaqit.project-init
description: Bootstrap a new smaqit project by generating a structured .github/copilot-instructions.md from a template. Use when the user asks to start a new smaqit project, init this project with smaqit, or set up smaqit for this project.
metadata:
  version: "0.2.0"
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

3. **Assess the repository to infer project details**
   - Scan the repository to gather as much context as possible without making assumptions. Read in parallel (whichever exist):
     - `README.md` — project name, purpose, description
     - `CONTRIBUTING.md` — conventions, branching strategy, contribution guidelines
     - Build/dependency manifests: `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `pom.xml`, `build.gradle` — tech stack, dependencies, scripts
     - `Makefile` — build, test, and lint commands; inferred conventions
     - Any `docs/` or `documentation/` index files
   - For each `# Project` placeholder field, derive the value only if the evidence is clear and unambiguous:
     - **Project name** — from the root `README.md` title, `package.json` `"name"`, or repository name
     - **Purpose / goal** — from the `README.md` introduction or description section
     - **Tech stack** — from manifest files (language runtimes, frameworks, key libraries)
     - **Key conventions** — from `CONTRIBUTING.md`, linting config files, or clearly documented patterns
     - **Domain context** — from `README.md` or `docs/` files that describe the business or architectural domain
   - **If the evidence for a field is absent, ambiguous, or insufficient, leave the original placeholder text exactly as it appears in the template. Do NOT invent or assume values.**

4. **Populate the `# Project` section**
   - Take the template content from Step 2.
   - Replace only the placeholders for which clear evidence was found in Step 3.
   - Keep the `# Scaffolding` section exactly as it appears in the template — do **not** modify it.

5. **Write the output file**
   - Write the populated content to `.github/copilot-instructions.md`.
   - Confirm success to the user and list which fields were filled in and which were left as placeholders:
     > ✓ `.github/copilot-instructions.md` created successfully. Review and commit the file to include it in your project.

## Requirements

- **Never overwrite** an existing `.github/copilot-instructions.md` (Step 1 is a hard guard).
- The `# Scaffolding` section must be copied verbatim from the template — it is static and must not be altered.
- **Never assume or invent** values for placeholder fields — only fill in what can be directly inferred from existing repo files.
- Placeholders must remain for any field that cannot be confidently inferred.
- Do **not** create any additional files beyond `.github/copilot-instructions.md`.
