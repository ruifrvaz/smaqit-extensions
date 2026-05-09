# smaqit-extensions Marketplace Registry

This directory contains the custom Copilot plugin marketplace registry for smaqit-extensions.

## What Is This?

The GitHub Copilot plugin ecosystem has three layers:

1. **Skills** — `SKILL.md` files with frontmatter declaring name, description, and invocation phrases. smaqit-extensions provides 20 skills.
2. **Plugins** — A `plugin.json` manifest that bundles agents and skills into a discoverable, installable unit.
3. **Marketplaces** — A `marketplace.json` registry file listing available plugins. Copilot clients query this to discover and install plugins.

The `marketplace.json` in this directory is the smaqit-extensions custom registry. It lists `smaqit-extensions` as its only plugin, pointing back to the root `plugin.json`.

## Registry Infrastructure

This custom registry uses the **smaqit-extensions GitHub repository itself** as the registry host. No separate server or additional repository is required — the marketplace is served via GitHub's raw file access.

**Registry identifier:** `ruifrvaz/smaqit-extensions`

## How to Add This Registry to Copilot

### In VS Code or Copilot CLI

Register the smaqit-extensions registry once:

```bash
copilot plugin marketplace add ruifrvaz/smaqit-extensions
```

> **Note:** If the `marketplace add` command requires a hosted JSON endpoint rather than a GitHub repo reference, host `marketplace.json` via GitHub Pages (see [Hosting via GitHub Pages](#hosting-via-github-pages) below) and use the Pages URL instead.

## How to Install smaqit-extensions from the Registry

After adding the registry, install the plugin:

```bash
copilot plugin install smaqit-extensions@smaqit-extensions
```

Or browse available plugins first:

```bash
/plugin marketplace browse smaqit-extensions
```

## What Gets Installed

Installing the `smaqit-extensions` plugin fetches `plugin.json` from the repository root and makes the following available in GitHub Copilot:

**Agents (3):**
- `smaqit.release.local` — Automated release management (local development)
- `smaqit.release.pr` — Automated release management (PR-based, CI/CD)
- `smaqit.user-testing` — End-to-end testing workflows

**Skills (20):**
- Session management: `smaqit.session-start`, `smaqit.session-finish`, `smaqit.session-assess`, `smaqit.session-title`, `smaqit.session-recap`
- Task tracking: `smaqit.task-create`, `smaqit.task-start`, `smaqit.task-list`, `smaqit.task-complete`
- Release: `smaqit.release-analysis`, `smaqit.release-approval`, `smaqit.release-prepare-files`, `smaqit.release-git-local`, `smaqit.release-git-pr`
- Project management: `smaqit.project-init`, `smaqit.project-glossary`, `smaqit.project-research`
- Testing: `smaqit.test-start`
- Utilities: `smaqit.utils.read-pdf`, `smaqit.utils.triage-issues`

## How This Differs from the Bash Installer

| Aspect | Bash Installer | Marketplace Plugin |
|--------|---------------|-------------------|
| Installation command | `curl -fsSL https://... \| bash` | `copilot plugin install smaqit-extensions@smaqit-extensions` |
| What gets installed | Files copied to `.github/` + `.smaqit/` scaffolding | Plugin registered in Copilot's plugin system |
| `.smaqit/` scaffolding | ✅ Created automatically | ❌ Not created (run `smaqit-extensions init` separately) |
| Update mechanism | Re-run installer or use `smaqit-extensions update` | `copilot plugin update smaqit-extensions` |
| Works without Git | ✅ | ✅ |
| Requires Copilot CLI | ❌ | ✅ |

Both methods install the same agents and skills. They are independent distribution channels — you can use either or both.

## Hosting via GitHub Pages

If the Copilot marketplace requires a hosted HTTP endpoint for the registry (rather than a `owner/repo` reference), enable GitHub Pages on this repository:

1. Go to `Settings → Pages`
2. Set source to `Deploy from a branch` → `main` → `/marketplace`
3. Access the registry at: `https://ruifrvaz.github.io/smaqit-extensions/marketplace.json`

Then register using the URL:
```bash
copilot plugin marketplace add https://ruifrvaz.github.io/smaqit-extensions/marketplace.json
```

## Version Sync

The `version` field in `marketplace.json` is kept in sync with `plugin.json` and `CHANGELOG.md` automatically during releases via the `smaqit.release-prepare-files` skill. No manual updates are needed.

## Files

| File | Purpose |
|------|---------|
| `marketplace.json` | Custom registry listing smaqit-extensions |
| `README.md` | This documentation |
