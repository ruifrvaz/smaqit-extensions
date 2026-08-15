---
status: Completed
created: "2026-05-09"
---

# Add smaqit-extensions update Self-Update Command

## Description

Add a new `smaqit-extensions update` CLI command to the Go installer binary. The command fetches the latest release from GitHub, downloads the new binary for the current platform, and replaces the running binary atomically. If the current working directory already contains a `.smaqit/` directory (indicating an initialized smaqit project), the command also re-runs `init` automatically to deploy updated agents, skills, and templates.

Currently users must: (1) manually download the latest release tarball from GitHub, (2) extract it, (3) run `smaqit-extensions init` to deploy updated skills/agents. The `update` command eliminates all three steps.

## Design Decisions (confirmed)

- **Platform:** Linux only for V1. No macOS or Windows self-update logic.
- **Binary location:** Use `/proc/self/exe` to detect the running binary path. Resolve symlinks with `filepath.EvalSymlinks()`.
- **Version comparison:** Simple semver string comparison. Fetch latest release tag from GitHub API, compare with embedded `Version` constant. If local version == latest, report "already up to date".
- **Auto-init:** After binary replacement, check if current working directory contains `.smaqit/` — if yes, automatically run the `init` command on the current directory to deploy updated assets.
- **GitHub API:** Reuse the same GitHub API pattern already used in `install.sh` — query `https://api.github.com/repos/ruifrvaz/smaqit-extensions/releases/latest`.

## Proposed Flow

```
smaqit-extensions update
  │
  ├── 1. Read current version (embedded Version constant)
  ├── 2. Query GitHub API for latest release tag + asset download URL
  ├── 3. Compare versions (semver string)
  │       ├── Equal → print "Already up to date (v0.10.0)" → exit 0
  │       └── Newer available → continue
  ├── 4. Download new binary to temp file (/tmp/smaqit-extensions.new)
  ├── 5. Set executable bit on temp file (chmod +x)
  ├── 6. Resolve current binary path (/proc/self/exe → symlink resolved)
  ├── 7. Atomic replace: rename temp file over current binary path
  │       (os.Rename — atomic on Linux if same filesystem; /tmp may be tmpfs)
  │       If /tmp is different filesystem: copy + rename instead of rename
  ├── 8. Report: "Updated to v0.11.0"
  ├── 9. Check if .smaqit/ exists in current working directory
  │       └── If yes → re-run init on current directory
  │               └── Report: "Re-initialized .github/ with updated assets"
  └── 10. Exit 0
```

## Atomic Replacement Strategy

`os.Rename` is atomic on Linux when source and destination are on the same filesystem. `/tmp` may be a `tmpfs` — a different filesystem from the binary location (e.g., `/usr/local/bin` or `~/.local/bin`). To handle cross-filesystem moves:

```go
// Try rename first (fast, atomic)
err := os.Rename(tmpPath, binaryPath)
if err != nil {
    // Fall back: copy to same directory as binary, then rename
    sameDir := filepath.Dir(binaryPath)
    tmpSameFS := filepath.Join(sameDir, ".smaqit-extensions.new")
    copyFile(tmpPath, tmpSameFS)
    os.Rename(tmpSameFS, binaryPath)
    os.Remove(tmpPath)
}
```

## GitHub API Integration

```go
type GithubRelease struct {
    TagName string        `json:"tag_name"`
    Assets  []GithubAsset `json:"assets"`
}

type GithubAsset struct {
    Name               string `json:"name"`
    BrowserDownloadURL string `json:"browser_download_url"`
}

// Query: GET https://api.github.com/repos/ruifrvaz/smaqit-extensions/releases/latest
// Find asset matching: "smaqit-extensions-linux-amd64" (or similar pattern)
// Download via HTTP GET with User-Agent header
```

## Asset Name Pattern

The GitHub release must include a Linux amd64 binary. Check the existing release workflow (`installer/Makefile` and the CI release workflow) to confirm the exact asset naming convention (e.g., `smaqit-extensions-linux-amd64`, `smaqit-extensions_linux_amd64`, etc.). Match that pattern exactly in the update command's asset lookup.

## Semver Comparison

Strip the leading `v` from both versions, split on `.`, compare as integers:

```go
func compareVersions(local, remote string) int {
    // strip "v" prefix
    // split by "."
    // compare major, minor, patch as integers
    // return -1 (local older), 0 (equal), 1 (local newer)
}
```

If the comparison fails to parse (malformed version), print a warning and abort without replacing.

## Implementation Steps

1. **Read `installer/main.go`** — understand the existing switch statement, `init` command implementation, embedded assets, and `Version` constant. Understand exactly how `init` deploys assets.

2. **Read `install.sh`** — understand the GitHub API query pattern and asset download approach already proven to work.

3. **Read `installer/Makefile`** — confirm the asset naming convention for Linux amd64 binaries.

4. **Add `case "update":` to the switch statement** in `main.go`. Call a `runUpdate()` function. At the top of `runUpdate()`, add a Linux-only guard: check `runtime.GOOS` and return an error if not `"linux"` (e.g., `"smaqit-extensions update is currently supported on Linux only"`). Add a `// TODO: add macOS/Windows support` comment at that point.

5. **Implement `runUpdate()`:**
   - getCurrentVersion() — return embedded `Version` constant
   - fetchLatestRelease() — HTTP GET GitHub API, parse JSON, return tag + download URL for linux-amd64 asset
   - compareVersions(local, remote string) int
   - downloadBinary(url, destPath string) error — download to temp file
   - replaceBinary(tmpPath, currentPath string) error — atomic replace (handle cross-filesystem)
   - checkAndReInit(dir string) — check for `.smaqit/`, run init if found

6. **Handle errors gracefully** — each step should print a clear error message and exit non-zero on failure. Do not leave a partial binary on disk.

7. **Add help text** — add `update` to the usage/help output in `main.go` so it appears when users run `smaqit-extensions help` or `smaqit-extensions` with no args.

8. **Update `installer/Makefile`** — ensure `update` is included in any integration test targets.

9. **Update `README.md`** — document the `update` command in the Usage section.

10. **Update `CHANGELOG.md`** — add entry for the new command.

## Acceptance Criteria

- [ ] `smaqit-extensions update` command exists and is handled in `installer/main.go`
- [ ] Command queries GitHub API for latest release and parses the response correctly
- [ ] Command compares local version (embedded constant) with remote version using semver comparison
- [ ] If already up to date: prints "Already up to date (vX.Y.Z)" and exits 0 without downloading anything
- [ ] If newer version available: downloads the linux-amd64 binary asset to a temp file
- [ ] Binary replacement is atomic (uses rename; handles cross-filesystem fallback)
- [ ] New binary has executable permissions set before replacement
- [ ] After successful replacement: prints "Updated from vA.B.C to vX.Y.Z"
- [ ] If current directory contains `.smaqit/`: automatically re-runs `init` on current directory and reports it
- [ ] If `.smaqit/` not present: skips re-init, reports "Run `smaqit-extensions init` to update your project assets"
- [ ] All error paths print clear messages and exit non-zero without corrupting the binary
- [ ] `/proc/self/exe` + `filepath.EvalSymlinks()` used for binary path detection
- [ ] `update` command appears in help/usage output
- [ ] `README.md` updated with `update` command documentation
- [ ] PLANNING.md updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `installer/main.go` | Modify — add `update` case + `runUpdate()` implementation |
| `README.md` | Modify — document `update` command |
| `CHANGELOG.md` | Modify — add entry |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- Linux-only for V1. Darwin and Windows paths are explicitly out of scope. Add a `// TODO: add macOS/Windows support` comment at the platform detection point.
- The running binary cannot be replaced while it is open on some systems. On Linux, this is safe — Linux allows replacing an open executable via rename because the inode is held open until the process exits. The new binary takes effect on next invocation.
- If the GitHub API rate-limits the request (403 or 429), print a helpful error: "GitHub API rate limit reached. Try again in a few minutes, or download manually from https://github.com/ruifrvaz/smaqit-extensions/releases"
- Do not store or cache the downloaded binary — if the atomic rename fails, clean up the temp file before exiting.
- The auto-init after update re-deploys agents, skills, and templates but does NOT overwrite `.smaqit/` project state (tasks, history, glossary). The `init` command already handles this correctly — verify this before relying on it.
