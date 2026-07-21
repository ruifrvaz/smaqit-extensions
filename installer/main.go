package main

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

//go:embed agents-copilot/*.md
var copilotAgentFiles embed.FS

//go:embed skills/*
var skillFiles embed.FS

//go:embed templates/*
var templateFiles embed.FS

//go:embed agents-claude/*.md
var claudeAgentFiles embed.FS

//go:embed commands-claude/*.md
var claudeCommandFiles embed.FS

//go:embed skills-claude
var skillFilesClaude embed.FS

//go:embed agents-codex/*.toml
var codexAgentFiles embed.FS

//go:embed skills-codex
var skillFilesCodex embed.FS

// Version is set via ldflags during build: -X main.Version=$(VERSION)
var Version = "1.6.0"

const planningTemplate = `# Task Planning

## Active

| ID | Title | Status | Notes |
|----|-------|--------|-------|

## Completed

| ID | Title | Completed | Notes |
|----|-------|-----------|-------|

## Abandoned

| ID | Title | Date | Reason |
|----|-------|------|--------|
`

func writeFileIfMissing(path string, content []byte, perm fs.FileMode) error {
	_, err := os.Stat(path)
	if err == nil {
		return nil
	}
	if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return os.WriteFile(path, content, perm)
}

// installFlatFiles copies every file directly under srcRoot in fsys to destDir
// (non-recursive — used for agent and command files, which are flat).
func installFlatFiles(fsys fs.FS, srcRoot, destDir string) (int, error) {
	count := 0
	err := fs.WalkDir(fsys, srcRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(fsys, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		targetPath := filepath.Join(destDir, filepath.Base(path))
		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		count++
		return nil
	})
	return count, err
}

// removeFlatFiles removes, from destDir, the file named after each file found
// directly under srcRoot in fsys (used for agent and command files).
func removeFlatFiles(fsys fs.FS, srcRoot, destDir string) (int, error) {
	count := 0
	err := fs.WalkDir(fsys, srcRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		targetPath := filepath.Join(destDir, filepath.Base(path))
		if removeErr := os.Remove(targetPath); removeErr == nil {
			count++
		}
		return nil
	})
	return count, err
}

// removeSkillTree removes, from destDir, each top-level skill directory found
// directly under srcRoot in fsys.
func removeSkillTree(fsys fs.FS, srcRoot, destDir string) (int, error) {
	entries, err := fs.ReadDir(fsys, srcRoot)
	if err != nil {
		return 0, err
	}
	count := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		skillPath := filepath.Join(destDir, entry.Name())
		if _, statErr := os.Stat(skillPath); statErr == nil {
			if removeErr := os.RemoveAll(skillPath); removeErr == nil {
				count++
			}
		}
	}
	return count, nil
}

// installSkillTree copies every file under srcRoot (srcRoot/<skill-name>/**) in
// fsys to destDir, preserving the nested structure, and returns the number of
// unique top-level skill directories installed.
func installSkillTree(fsys fs.FS, srcRoot, destDir string) (int, error) {
	seen := make(map[string]bool)
	prefix := srcRoot + "/"
	err := fs.WalkDir(fsys, srcRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(fsys, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		relPath := filepath.ToSlash(path)
		if !strings.HasPrefix(relPath, prefix) {
			return nil
		}
		skillRelPath := strings.TrimPrefix(relPath, prefix)
		skillName := strings.SplitN(skillRelPath, "/", 2)[0]
		seen[skillName] = true

		targetPath := filepath.Join(destDir, skillRelPath)
		targetDir := filepath.Dir(targetPath)
		if err := os.MkdirAll(targetDir, 0755); err != nil {
			return fmt.Errorf("creating directory %s: %w", targetDir, err)
		}
		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		return nil
	})
	return len(seen), err
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "version", "--version", "-v":
			fmt.Printf("smaqit-extensions %s\n", Version)
			return
		case "help", "--help", "-h":
			printHelp()
			return
		case "uninstall":
			cmdUninstall()
			return
		case "update":
			runUpdate()
			return
		case "init":
			targetDir := "."
			if len(os.Args) > 2 {
				targetDir = os.Args[2]
			}
			cmdInstall(targetDir)
			return
		}
	}

	// Default: show help
	printHelp()
}

func printHelp() {
	fmt.Println("smaQit-extensions - Quality-of-life workflow agents and skills")
	fmt.Printf("Version: %s\n\n", Version)
	fmt.Println("Usage: smaqit-extensions <command> [args]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  smaqit-extensions init           Install extensions in current directory")
	fmt.Println("  smaqit-extensions init <dir>     Install extensions in specified directory")
	fmt.Println("  smaqit-extensions update         Update to the latest release")
	fmt.Println("  smaqit-extensions uninstall      Remove extensions from current directory")
	fmt.Println("  smaqit-extensions version        Show version")
	fmt.Println("  smaqit-extensions --help         Show this help message")
	fmt.Println()
	fmt.Println("What gets installed:")
	fmt.Println("  .github/agents/     - 3 utility agents (GitHub Copilot)")
	fmt.Println("  .github/skills/     - 28 workflow skills (GitHub Copilot)")
	fmt.Println("  .claude/agents/     - 3 utility agents (Claude Code)")
	fmt.Println("  .claude/commands/   - 3 slash commands (Claude Code)")
	fmt.Println("  .claude/skills/     - 28 workflow skills (Claude Code)")
	fmt.Println("  .codex/agents/      - 3 utility agents (Codex)")
	fmt.Println("  .agents/skills/     - 28 workflow skills (Codex)")
	fmt.Println("  .smaqit/templates/  - 3 canonical templates")
}

func cmdInstall(targetDir string) {
	// Create target directories
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")
	claudeAgentsDir := filepath.Join(targetDir, ".claude", "agents")
	claudeCommandsDir := filepath.Join(targetDir, ".claude", "commands")
	claudeSkillsDir := filepath.Join(targetDir, ".claude", "skills")
	codexAgentsDir := filepath.Join(targetDir, ".codex", "agents")
	codexSkillsDir := filepath.Join(targetDir, ".agents", "skills")
	smaqitDir := filepath.Join(targetDir, ".smaqit")
	tasksDir := filepath.Join(smaqitDir, "tasks")
	historyDir := filepath.Join(smaqitDir, "history")
	userTestingDir := filepath.Join(smaqitDir, "user-testing")
	templatesDir := filepath.Join(smaqitDir, "templates")

	if err := os.MkdirAll(agentsDir, 0755); err != nil {
		fmt.Printf("Error creating agents directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(skillsDir, 0755); err != nil {
		fmt.Printf("Error creating skills directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(claudeAgentsDir, 0755); err != nil {
		fmt.Printf("Error creating Claude agents directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(claudeCommandsDir, 0755); err != nil {
		fmt.Printf("Error creating Claude commands directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(claudeSkillsDir, 0755); err != nil {
		fmt.Printf("Error creating Claude skills directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(codexAgentsDir, 0755); err != nil {
		fmt.Printf("Error creating Codex agents directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(codexSkillsDir, 0755); err != nil {
		fmt.Printf("Error creating Codex skills directory: %v\n", err)
		os.Exit(1)
	}

	// Create .smaqit scaffolding used by agents/skills
	if err := os.MkdirAll(tasksDir, 0755); err != nil {
		fmt.Printf("Error creating tasks directory: %v\n", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(historyDir, 0755); err != nil {
		fmt.Printf("Error creating history directory: %v\n", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(userTestingDir, 0755); err != nil {
		fmt.Printf("Error creating user-testing directory: %v\n", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(templatesDir, 0755); err != nil {
		fmt.Printf("Error creating templates directory: %v\n", err)
		os.Exit(1)
	}

	planningPath := filepath.Join(tasksDir, "PLANNING.md")
	if err := writeFileIfMissing(planningPath, []byte(planningTemplate), 0644); err != nil {
		fmt.Printf("Error creating planning file: %v\n", err)
		os.Exit(1)
	}

	// Install template files (never overwrite existing ones)
	if err := fs.WalkDir(templateFiles, "templates", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(templateFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		filename := filepath.Base(path)
		targetPath := filepath.Join(templatesDir, filename)

		if err := writeFileIfMissing(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		return nil
	}); err != nil {
		fmt.Printf("Error installing templates: %v\n", err)
		os.Exit(1)
	}

	// Install agents
	agentCount, err := installFlatFiles(copilotAgentFiles, "agents-copilot", agentsDir)
	if err != nil {
		fmt.Printf("Error installing agents: %v\n", err)
		os.Exit(1)
	}

	// Install skills
	seenSkillDirs := make(map[string]bool)
	if err := fs.WalkDir(skillFiles, "skills", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(skillFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		// Extract relative path from skills/ root
		// path format: skills/skill-name/SKILL.md or skills/skill-name/references/RULES.md
		relPath := filepath.ToSlash(path)
		if !strings.HasPrefix(relPath, "skills/") {
			return nil
		}

		// Remove "skills/" prefix to get skill-relative path
		skillRelPath := strings.TrimPrefix(relPath, "skills/")

		// Track unique top-level skill directories so the reported count
		// reflects installed skills, not individual files within each skill.
		skillName := strings.SplitN(skillRelPath, "/", 2)[0]
		seenSkillDirs[skillName] = true

		// Create target path
		targetPath := filepath.Join(skillsDir, skillRelPath)
		targetDir := filepath.Dir(targetPath)

		if err := os.MkdirAll(targetDir, 0755); err != nil {
			return fmt.Errorf("creating directory %s: %w", targetDir, err)
		}

		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		return nil
	}); err != nil {
		fmt.Printf("Error installing skills: %v\n", err)
		os.Exit(1)
	}
	skillCount := len(seenSkillDirs)

	// Install Claude Code agents, commands, and skills alongside the GitHub Copilot output.
	claudeAgentCount, err := installFlatFiles(claudeAgentFiles, "agents-claude", claudeAgentsDir)
	if err != nil {
		fmt.Printf("Error installing Claude agents: %v\n", err)
		os.Exit(1)
	}

	claudeCommandCount, err := installFlatFiles(claudeCommandFiles, "commands-claude", claudeCommandsDir)
	if err != nil {
		fmt.Printf("Error installing Claude commands: %v\n", err)
		os.Exit(1)
	}

	claudeSkillCount, err := installSkillTree(skillFilesClaude, "skills-claude", claudeSkillsDir)
	if err != nil {
		fmt.Printf("Error installing Claude skills: %v\n", err)
		os.Exit(1)
	}

	// Install Codex agents and skills from generated, platform-resolved artifacts.
	codexAgentCount, err := installFlatFiles(codexAgentFiles, "agents-codex", codexAgentsDir)
	if err != nil {
		fmt.Printf("Error installing Codex agents: %v\n", err)
		os.Exit(1)
	}

	codexSkillCount, err := installSkillTree(skillFilesCodex, "skills-codex", codexSkillsDir)
	if err != nil {
		fmt.Printf("Error installing Codex skills: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✓ Installed %d agents to %s\n", agentCount, agentsDir)
	fmt.Printf("✓ Installed %d skills to %s\n", skillCount, skillsDir)
	fmt.Printf("✓ Installed %d agents to %s\n", claudeAgentCount, claudeAgentsDir)
	fmt.Printf("✓ Installed %d commands to %s\n", claudeCommandCount, claudeCommandsDir)
	fmt.Printf("✓ Installed %d skills to %s\n", claudeSkillCount, claudeSkillsDir)
	fmt.Printf("✓ Installed %d agents to %s\n", codexAgentCount, codexAgentsDir)
	fmt.Printf("✓ Installed %d skills to %s\n", codexSkillCount, codexSkillsDir)
	fmt.Println()
	fmt.Println("Extensions installed successfully!")
	fmt.Println()
	fmt.Println("Get started:")
	fmt.Println("  GitHub Copilot — agents: @smaqit.release.local, @smaqit.release.pr, @smaqit.user-testing")
	fmt.Println("  GitHub Copilot — skills: available via direct invocation")
	fmt.Println("  Claude Code — agents: /smaqit.release.local, /smaqit.release.pr, /smaqit.user-testing")
	fmt.Println("  Claude Code — skills: available via direct invocation")
	fmt.Println("  Codex — agents: ask Codex to spawn smaqit.release.local, smaqit.release.pr, or smaqit.user-testing")
	fmt.Println("  Codex — skills: invoke with $, or select with /skills")
}

func cmdUninstall() {
	targetDir := "."
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")
	claudeAgentsDir := filepath.Join(targetDir, ".claude", "agents")
	claudeCommandsDir := filepath.Join(targetDir, ".claude", "commands")
	claudeSkillsDir := filepath.Join(targetDir, ".claude", "skills")
	codexAgentsDir := filepath.Join(targetDir, ".codex", "agents")
	codexSkillsDir := filepath.Join(targetDir, ".agents", "skills")

	removedCount := 0

	// Remove agents: discover from embedded FS
	agentRemoved, err := removeFlatFiles(copilotAgentFiles, "agents-copilot", agentsDir)
	if err != nil {
		fmt.Printf("Error enumerating agents: %v\n", err)
		os.Exit(1)
	}
	removedCount += agentRemoved

	// Remove skills: discover top-level skill directories from embedded FS
	entries, err := skillFiles.ReadDir("skills")
	if err != nil {
		fmt.Printf("Error enumerating skills: %v\n", err)
		os.Exit(1)
	}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		skillPath := filepath.Join(skillsDir, entry.Name())
		if _, statErr := os.Stat(skillPath); statErr == nil {
			if removeErr := os.RemoveAll(skillPath); removeErr == nil {
				removedCount++
			}
		}
	}

	// Remove Claude Code agents, commands, and skills alongside the GitHub Copilot output.
	claudeAgentRemoved, err := removeFlatFiles(claudeAgentFiles, "agents-claude", claudeAgentsDir)
	if err != nil {
		fmt.Printf("Error enumerating Claude agents: %v\n", err)
		os.Exit(1)
	}
	removedCount += claudeAgentRemoved

	claudeCommandRemoved, err := removeFlatFiles(claudeCommandFiles, "commands-claude", claudeCommandsDir)
	if err != nil {
		fmt.Printf("Error enumerating Claude commands: %v\n", err)
		os.Exit(1)
	}
	removedCount += claudeCommandRemoved

	claudeSkillRemoved, err := removeSkillTree(skillFilesClaude, "skills-claude", claudeSkillsDir)
	if err != nil {
		fmt.Printf("Error enumerating Claude skills: %v\n", err)
		os.Exit(1)
	}
	removedCount += claudeSkillRemoved

	// Remove only the Codex artifacts represented in the embedded filesystem.
	codexAgentRemoved, err := removeFlatFiles(codexAgentFiles, "agents-codex", codexAgentsDir)
	if err != nil {
		fmt.Printf("Error enumerating Codex agents: %v\n", err)
		os.Exit(1)
	}
	removedCount += codexAgentRemoved

	codexSkillRemoved, err := removeSkillTree(skillFilesCodex, "skills-codex", codexSkillsDir)
	if err != nil {
		fmt.Printf("Error enumerating Codex skills: %v\n", err)
		os.Exit(1)
	}
	removedCount += codexSkillRemoved

	if removedCount > 0 {
		fmt.Printf("✓ Removed %d extension files\n", removedCount)
		fmt.Println("Extensions uninstalled successfully!")
	} else {
		fmt.Println("No extension files found to remove")
	}
}

// githubRelease holds the fields we care about from the GitHub releases API.
type githubRelease struct {
	TagName string        `json:"tag_name"`
	Assets  []githubAsset `json:"assets"`
}

type githubAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

// runUpdate self-updates the binary to the latest GitHub release.
func runUpdate() {
	localVersion := Version

	release, err := fetchLatestRelease()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching latest release: %v\n", err)
		os.Exit(1)
	}

	remoteVersion := strings.TrimPrefix(release.TagName, "v")
	localVersionTrimmed := strings.TrimPrefix(localVersion, "v")

	cmp, err := compareVersions(localVersionTrimmed, remoteVersion)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error comparing versions: %v\n", err)
		os.Exit(1)
	}
	if cmp == 0 {
		fmt.Printf("Already up to date (%s)\n", localVersion)
		checkAndReInit(".")
		return
	}
	if cmp > 0 {
		fmt.Printf("Local version (%s) is newer than latest release (%s). Nothing to do.\n", localVersion, release.TagName)
		checkAndReInit(".")
		return
	}

	// Build the asset name for the current platform and architecture.
	assetName := fmt.Sprintf("smaqit-extensions_%s_%s", runtime.GOOS, runtime.GOARCH)
	if runtime.GOOS == "windows" {
		assetName += ".exe"
	}
	var downloadURL string
	for _, asset := range release.Assets {
		if asset.Name == assetName {
			downloadURL = asset.BrowserDownloadURL
			break
		}
	}
	if downloadURL == "" {
		fmt.Fprintf(os.Stderr, "No asset named %q found in release %s\n", assetName, release.TagName)
		os.Exit(1)
	}

	tmpFile := filepath.Join(os.TempDir(), "smaqit-extensions.new")
	if err := downloadBinary(downloadURL, tmpFile); err != nil {
		_ = os.Remove(tmpFile)
		fmt.Fprintf(os.Stderr, "Error downloading binary: %v\n", err)
		os.Exit(1)
	}

	if err := os.Chmod(tmpFile, 0755); err != nil {
		_ = os.Remove(tmpFile)
		fmt.Fprintf(os.Stderr, "Error setting executable bit: %v\n", err)
		os.Exit(1)
	}

	// Resolve current binary path using os.Executable (cross-platform).
	currentBin, err := os.Executable()
	if err != nil {
		_ = os.Remove(tmpFile)
		fmt.Fprintf(os.Stderr, "Error detecting binary path: %v\n", err)
		os.Exit(1)
	}
	currentBin, err = filepath.EvalSymlinks(currentBin)
	if err != nil {
		_ = os.Remove(tmpFile)
		fmt.Fprintf(os.Stderr, "Error resolving binary path: %v\n", err)
		os.Exit(1)
	}

	if err := replaceBinary(tmpFile, currentBin); err != nil {
		_ = os.Remove(tmpFile)
		fmt.Fprintf(os.Stderr, "Error replacing binary: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Updated from %s to %s\n", localVersion, release.TagName)

	checkAndReInit(".")
}

// fetchLatestRelease queries the GitHub API and returns release metadata.
func fetchLatestRelease() (*githubRelease, error) {
	const apiURL = "https://api.github.com/repos/ruifrvaz/smaqit-extensions/releases/latest"

	req, err := http.NewRequest(http.MethodGet, apiURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "smaqit-extensions/"+Version)
	req.Header.Set("Accept", "application/vnd.github+json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusTooManyRequests {
		return nil, fmt.Errorf("GitHub API rate limit reached. Try again in a few minutes, or download manually from https://github.com/ruifrvaz/smaqit-extensions/releases")
	}
	if resp.StatusCode == http.StatusForbidden {
		return nil, fmt.Errorf("GitHub API request forbidden (status 403). Check your network or try again later")
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GitHub API returned status %d", resp.StatusCode)
	}

	var release githubRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return nil, fmt.Errorf("parsing GitHub API response: %w", err)
	}
	if release.TagName == "" {
		return nil, fmt.Errorf("no tag_name in GitHub API response")
	}
	return &release, nil
}

// compareVersions compares two semver strings (without leading "v").
// Returns -1 if a < b, 0 if equal, 1 if a > b, and a non-nil error if
// either version string cannot be parsed.
func compareVersions(a, b string) (int, error) {
	parse := func(v string) ([]int, error) {
		parts := strings.Split(v, ".")
		nums := make([]int, len(parts))
		for i, p := range parts {
			n, err := strconv.Atoi(p)
			if err != nil {
				return nil, fmt.Errorf("invalid version segment %q in %q", p, v)
			}
			nums[i] = n
		}
		return nums, nil
	}

	av, aerr := parse(a)
	bv, berr := parse(b)
	if aerr != nil {
		return 0, aerr
	}
	if berr != nil {
		return 0, berr
	}

	// Pad shorter slice
	for len(av) < len(bv) {
		av = append(av, 0)
	}
	for len(bv) < len(av) {
		bv = append(bv, 0)
	}

	for i := range av {
		if av[i] < bv[i] {
			return -1, nil
		}
		if av[i] > bv[i] {
			return 1, nil
		}
	}
	return 0, nil
}

// downloadBinary downloads url into destPath.
func downloadBinary(url, destPath string) error {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "smaqit-extensions/"+Version)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download returned status %d", resp.StatusCode)
	}

	f, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer f.Close()

	if _, err := io.Copy(f, resp.Body); err != nil {
		return err
	}
	return nil
}

// replaceBinary atomically replaces currentPath with tmpPath.
// Falls back to a same-filesystem copy + rename when /tmp is on a different
// filesystem than the binary (e.g., tmpfs vs ext4).
func replaceBinary(tmpPath, currentPath string) error {
	// Fast path: rename is atomic if src and dst are on the same filesystem.
	if err := os.Rename(tmpPath, currentPath); err == nil {
		return nil
	}

	// Fallback: write to a temp file in the same directory, then rename.
	sameDir := filepath.Dir(currentPath)
	tmpSameFS := filepath.Join(sameDir, fmt.Sprintf(".smaqit-extensions-%d.new", os.Getpid()))

	if err := copyFile(tmpPath, tmpSameFS); err != nil {
		_ = os.Remove(tmpSameFS)
		return fmt.Errorf("copy to same filesystem: %w", err)
	}
	if err := os.Chmod(tmpSameFS, 0755); err != nil {
		_ = os.Remove(tmpSameFS)
		return err
	}
	if err := os.Rename(tmpSameFS, currentPath); err != nil {
		_ = os.Remove(tmpSameFS)
		return fmt.Errorf("rename on same filesystem: %w", err)
	}
	_ = os.Remove(tmpPath)
	return nil
}

// copyFile copies src to dst, creating dst if necessary.
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err = io.Copy(out, in); err != nil {
		return fmt.Errorf("copying file: %w", err)
	}
	return nil
}

// checkAndReInit checks whether dir contains a .smaqit/ directory. If so it
// re-runs the init command to deploy updated agents, skills, and templates.
func checkAndReInit(dir string) {
	smaqitPath := filepath.Join(dir, ".smaqit")
	if _, err := os.Stat(smaqitPath); err != nil {
		// .smaqit/ not present — skip auto-init
		fmt.Println("Run `smaqit-extensions init` to update your project assets")
		return
	}

	fmt.Println("Detected .smaqit/ — re-initializing project assets...")
	cmdInstall(dir)
	fmt.Println("Re-initialized .github/, .claude/, .codex/, and .agents/ with updated assets")
}
