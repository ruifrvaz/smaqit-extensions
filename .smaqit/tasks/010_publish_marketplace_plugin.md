---
status: Not Started
created: "2026-05-09"
---

# Publish smaqit-extensions as Copilot Marketplace Plugin

## Description

Extend smaqit-extensions distribution by packaging it as an installable plugin for the GitHub Copilot and VS Code agent/skill marketplace ecosystem. This is a side-by-side distribution channel — the existing bash installer (`install.sh`) and the Go binary remain unchanged and fully functional. The marketplace plugin is an additional, parallel distribution method. No cross-dependencies between the two paths.

The marketplace plugin distribution is based on the ecosystem described at:
`https://chris-ayers.com/posts/agent-skills-plugins-marketplace`

A custom registry will be established (details TBD — this task includes researching what a custom registry requires and setting it up). The plugin will NOT be published to the global `awesome-copilot` community marketplace initially — it will live in a custom registry that can be shared or made public later.

Claude plugin support is NOT included in V1. GitHub Copilot only.

## Design Decisions (confirmed)

- **Distribution:** Custom registry (not the public `awesome-copilot` registry). Research required: understand what infrastructure a custom marketplace registry requires, then set it up.
- **Cross-tool:** No. GitHub Copilot only. No `.claude-plugin/` manifest.
- **Relationship to existing installer:** Side-by-side. Both distribution methods must work independently. No shared logic, no cross-dependencies. Duplicate configuration where needed.
- **Version sync:** `plugin.json` version field must auto-sync with the Git tag / CHANGELOG version during release automation. The existing release workflow must be extended to update `plugin.json` version on release.
- **Auto-sync mechanism:** The `smaqit.release-prepare-files` skill (or the release git workflow) currently updates `CHANGELOG.md` and any version files. `plugin.json` must be added to that list.

## What is a Copilot Marketplace Plugin

Based on the reference blog post, the plugin ecosystem has three layers:

1. **Skills** — `SKILL.md` files with frontmatter declaring name, description, how-to-invoke. Already present in smaqit-extensions.
2. **Plugins** — A `plugin.json` manifest that declares the bundle: which agents, which skills, metadata (name, version, description, author, keywords, license). This is what makes smaqit-extensions discoverable and installable as a unit.
3. **Marketplaces** — A `marketplace.json` registry file (hosted in a Git repo or as a public URL) that lists available plugins. Copilot clients query this registry to discover plugins.

## Plugin Manifest: plugin.json

Location: `.github/plugin.json` (or project root — confirm with reference)

```json
{
  "$schema": "https://schemas.copilot.com/plugin/v1",
  "name": "smaqit-extensions",
  "version": "0.10.0",
  "description": "Quality-of-life workflows, agents, and skills for GitHub Copilot. Includes session management, task tracking, release automation, and testing workflows.",
  "author": "ruifrvaz",
  "license": "MIT",
  "keywords": ["smaqit", "session", "tasks", "release", "workflow", "agents", "skills"],
  "repository": "https://github.com/ruifrvaz/smaqit-extensions",
  "agents": [
    "agents/smaqit.release.local.agent.md",
    "agents/smaqit.release.pr.agent.md",
    "agents/smaqit.user-testing.agent.md"
  ],
  "skills": [
    "skills/smaqit.compendium/",
    "skills/smaqit.project-glossary/",
    "skills/smaqit.project-init/",
    "skills/smaqit.project-recap/",
    "skills/smaqit.project-research/",
    "skills/smaqit.release-analysis/",
    "skills/smaqit.release-approval/",
    "skills/smaqit.release-git-local/",
    "skills/smaqit.release-git-pr/",
    "skills/smaqit.release-prepare-files/",
    "skills/smaqit.session-assess/",
    "skills/smaqit.session-finish/",
    "skills/smaqit.session-recap/",
    "skills/smaqit.session-start/",
    "skills/smaqit.session-title/",
    "skills/smaqit.task-complete/",
    "skills/smaqit.task-create/",
    "skills/smaqit.task-list/",
    "skills/smaqit.task-start/",
    "skills/smaqit.test-start/",
    "skills/smaqit.utils.read-pdf/",
    "skills/smaqit.utils.triage-issues/"
  ]
}
```

**Note:** The exact `$schema` URL and field names must be confirmed against the reference blog post and any linked specification. Use the actual schema, not the placeholder above.

## Custom Registry: Research and Setup

This task includes researching and setting up the custom marketplace registry. Key questions to answer during implementation:

1. **What does a custom registry require?** Is it a Git repository with a `marketplace.json` file? A hosted JSON endpoint? A GitHub Pages site? Read the reference and any linked specs to determine exactly what is needed.
2. **Where does the registry live?** Options: (a) a separate `smaqit-marketplace` GitHub repository, (b) a subdirectory of smaqit-extensions (e.g., `marketplace/`), (c) a GitHub Gist, (d) a GitHub Pages endpoint.
3. **What does `marketplace.json` look like?** What fields are required? How does it reference the plugin?
4. **How does a user add the custom registry to Copilot?** What configuration does the user need to add to their VS Code or Copilot Desktop settings?
5. **How does a user install smaqit-extensions from the registry?** What is the one-command install experience?

Document all answers in `marketplace/README.md` as part of this task.

## Release Automation Integration

The existing release workflow must be extended to update `plugin.json` on release:

- Identify where version files are updated in the release pipeline (likely in `smaqit.release-prepare-files` skill)
- Add `plugin.json` version field update to that step
- The update must follow the same pattern as CHANGELOG.md version updates — automated, not manual

Specifically in `skills/smaqit.release-prepare-files/SKILL.md`: add a step to update `"version"` in `plugin.json` (and `marketplace.json` if it contains a version reference) when preparing the release.

## Implementation Steps

1. **Research the reference** — fetch and read `https://chris-ayers.com/posts/agent-skills-plugins-marketplace` thoroughly. Understand exactly what `plugin.json` schema to use, what a marketplace registry looks like, and how custom registries work.

2. **Create `plugin.json`** — write the manifest at the correct location (confirm location from reference). Use actual schema. List all current agents and skills.

3. **Research custom registry requirements** — determine the registry format, hosting location, and user-facing install UX. Document findings.

4. **Set up the custom registry** — create the registry (new repo, subdirectory, or GitHub Pages endpoint based on findings). Write the `marketplace.json` listing smaqit-extensions.

5. **Write `marketplace/README.md`** (or equivalent) — document: what the registry is, how users add it to Copilot, how users install smaqit-extensions from it, how it differs from the bash installer.

6. **Update `skills/smaqit.release-prepare-files/SKILL.md`** — add `plugin.json` version update step. Bump skill version.

7. **Update root `Makefile`** — add a `plugin:validate` target that checks `plugin.json` version matches the latest CHANGELOG version (for CI consistency checks).

8. **Update `README.md`** — add marketplace distribution section with install instructions, alongside existing bash installer instructions.

9. **Sync modified skills** — run `make sync` after updating `release-prepare-files`.

10. **Update `CHANGELOG.md`** — add entry for marketplace plugin distribution.

## Acceptance Criteria

- [ ] `plugin.json` created at the correct location per the reference specification
- [ ] `plugin.json` contains all required fields: name, version, description, author, license, keywords, repository, agents array, skills array
- [ ] All current agents and skills are listed in `plugin.json`
- [ ] Custom registry researched and set up: registry exists and is accessible
- [ ] `marketplace.json` (or equivalent registry file) lists smaqit-extensions with correct metadata and download/reference URL
- [ ] A user can discover and install smaqit-extensions from the custom registry using the Copilot plugin install mechanism
- [ ] Installation instructions for the custom registry are documented in `README.md` and `marketplace/README.md`
- [ ] `skills/smaqit.release-prepare-files/SKILL.md` updated to include `plugin.json` version update step
- [ ] `plugin.json` version automatically stays in sync after running the release workflow
- [ ] `README.md` updated with marketplace section (side-by-side with bash installer section)
- [ ] `CHANGELOG.md` updated with entry
- [ ] Existing `install.sh` and Go binary installer are completely unaffected
- [ ] PLANNING.md updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `plugin.json` (location TBD) | Create |
| `marketplace/README.md` (or equivalent) | Create |
| `marketplace.json` (location TBD — may be in a separate repo) | Create |
| `skills/smaqit.release-prepare-files/SKILL.md` | Modify — add plugin.json version update; bump version |
| `.github/skills/smaqit.release-prepare-files/SKILL.md` | Synced via `make sync` |
| `Makefile` | Modify — add plugin:validate target |
| `README.md` | Modify — add marketplace section |
| `CHANGELOG.md` | Modify — add entry |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- This task is partially research-driven. The implementer must read the reference URL and any linked specifications to determine the exact format of `plugin.json` and the registry before writing any files. Do not guess the schema.
- The custom registry may require creating a new GitHub repository. If so, document the repository name in this task file and update with the URL once created.
- No cross-dependencies with the bash installer or Go binary. If the plugin manifest lists paths that are only valid in the GitHub repo context (for marketplace discovery), that is fine — the bash installer uses a completely different mechanism.
- Version sync: the version in `plugin.json` must always match the latest git tag after a release. The release-prepare-files skill update ensures this.
- If the custom registry infrastructure is significantly more complex than expected (e.g., requires a server), flag the blocker and document what would be needed, rather than implementing a workaround.
