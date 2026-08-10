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
	"os/exec"
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

//go:embed workflow-templates/*
var workflowTemplateFiles embed.FS

//go:embed agents-claude/*.md
var claudeAgentFiles embed.FS

//go:embed commands-claude/*.md
var claudeCommandFiles embed.FS

//go:embed skills-claude
var skillFilesClaude embed.FS

//go:embed agents-codex/*.toml
var codexAgentFiles embed.FS

// Version is set via ldflags during build: -X main.Version=$(VERSION)
var Version = "1.13.0"

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

// resolveGlobalDir returns the global installation directory for a given agent,
// respecting environment variable overrides. The special value "skills" returns
// the shared skills directory (~/.agents/skills).
func resolveGlobalDir(agent string) string {
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving home directory: %v\n", err)
		os.Exit(1)
	}

	switch agent {
	case "copilot":
		if d := os.Getenv("COPILOT_HOME"); d != "" {
			return filepath.Join(d, "agents")
		}
		return filepath.Join(home, ".copilot", "agents")
	case "claude":
		if d := os.Getenv("CLAUDE_CONFIG_DIR"); d != "" {
			return filepath.Join(d, "agents")
		}
		return filepath.Join(home, ".claude", "agents")
	case "codex":
		if d := os.Getenv("CODEX_HOME"); d != "" {
			return filepath.Join(d, "agents")
		}
		return filepath.Join(home, ".codex", "agents")
	case "skills":
		return filepath.Join(home, ".agents", "skills")
	case "skills-claude":
		if d := os.Getenv("CLAUDE_CONFIG_DIR"); d != "" {
			return filepath.Join(d, "skills")
		}
		return filepath.Join(home, ".claude", "skills")
	case "commands":
		if d := os.Getenv("CLAUDE_CONFIG_DIR"); d != "" {
			return filepath.Join(d, "commands")
		}
		return filepath.Join(home, ".claude", "commands")
	default:
		fmt.Fprintf(os.Stderr, "Unknown agent: %s\n", agent)
		os.Exit(1)
		return ""
	}
}

// parseAgentFilter extracts the --agent flag value and returns the set of
// agents to install. Returns all agents if --agent is absent or "all".
func parseAgentFilter(args []string) map[string]bool {
	all := map[string]bool{"copilot": true, "claude": true, "codex": true}
	for i, a := range args {
		if a == "--agent" && i+1 < len(args) {
			val := args[i+1]
			switch val {
			case "all":
				return all
			case "copilot":
				return map[string]bool{"copilot": true}
			case "claude":
				return map[string]bool{"claude": true}
			case "codex":
				return map[string]bool{"codex": true}
			}
		}
	}
	return all
}

// parseScope extracts the --scope flag value. Returns "user" by default.
func parseScope(args []string) string {
	for i, a := range args {
		if a == "--scope" && i+1 < len(args) {
			return args[i+1]
		}
	}
	return "user"
}

func installReleaseWorkflow(targetDir string) {
	if err := fs.WalkDir(workflowTemplateFiles, "workflow-templates", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		content, err := fs.ReadFile(workflowTemplateFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}
		targetPath := filepath.Join(targetDir, filepath.Base(path))
		if err := writeFileIfMissing(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}
		return nil
	}); err != nil {
		fmt.Printf("Error installing release workflow: %v\n", err)
		os.Exit(1)
	}
}

// scaffoldProject scaffolds .smaqit/ and the release workflow into the given
// project directory. Used by both the default no-args path and the init alias.
func scaffoldProject(targetDir string) {
	scaffoldSmaqit(targetDir)
	workflowsDir := filepath.Join(targetDir, ".github", "workflows")
	if err := os.MkdirAll(workflowsDir, 0755); err != nil {
		fmt.Printf("Error creating workflows directory: %v\n", err)
		os.Exit(1)
	}
	installReleaseWorkflow(workflowsDir)
	fmt.Println("✓ Project scaffolding complete")
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
		case "--install-global":
			installGlobal(parseAgentFilter(nil))
			return
		case "install":
			// Internal/testing alias — supports --scope project for smoke tests.
			cmdInstall(os.Args[2:])
			return
		case "uninstall":
			cmdUninstallArgs(os.Args[2:])
			return
		case "update":
			runUpdate()
			return
		case "init":
			if len(os.Args) > 2 {
				scaffoldProject(os.Args[2])
			} else {
				scaffoldProject(resolveDefaultProjectDir("."))
			}
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
	fmt.Println("  smaqit-extensions init             Scaffold .smaqit/ tracking in current project")
	fmt.Println("  smaqit-extensions init <dir>       Scaffold .smaqit/ tracking in specified directory")
	fmt.Println("  smaqit-extensions update           Update binary and refresh global install")
	fmt.Println("  smaqit-extensions uninstall       Remove extensions from global paths")
	fmt.Println("  smaqit-extensions uninstall --scope project  Remove extensions from project directory")
	fmt.Println("  smaqit-extensions version         Show version")
	fmt.Println("  smaqit-extensions --help          Show this help message")
	fmt.Println()
	fmt.Println("Installation:")
	fmt.Println("  curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | bash")
	fmt.Println()
	fmt.Println("The installer downloads the binary and runs global agent/skill installation")
	fmt.Println("automatically. After that, run smaqit-extensions in any project directory to")
	fmt.Println("scaffold the .smaqit/ tracking directory and release workflow.")
	fmt.Println()
	fmt.Println("Global installation paths:")
	fmt.Println("  ~/.agents/skills/     - Shared skills (GitHub Copilot + Codex)")
	fmt.Println("  ~/.copilot/agents/    - GitHub Copilot custom agents")
	fmt.Println("  ~/.claude/agents/     - Claude Code subagents")
	fmt.Println("  ~/.claude/commands/   - Claude Code slash commands")
	fmt.Println("  ~/.claude/skills/     - Claude Code skills")
	fmt.Println("  ~/.codex/agents/      - Codex custom agents")
	fmt.Println()
	fmt.Println("Environment overrides:")
	fmt.Println("  COPILOT_HOME          Override Copilot install root (default: ~/.copilot)")
	fmt.Println("  CLAUDE_CONFIG_DIR     Override Claude install root (default: ~/.claude)")
	fmt.Println("  CODEX_HOME            Override Codex install root (default: ~/.codex)")
	fmt.Println()
	fmt.Println("Project scaffolding creates:")
	fmt.Println("  .smaqit/tasks/        - Task tracking")
	fmt.Println("  .smaqit/history/      - Session history")
	fmt.Println("  .smaqit/templates/    - Canonical templates")
	fmt.Println("  .github/workflows/    - post-merge-release.yml (create-if-absent)")
}

// cmdInstall is the entry point for the "install" subcommand.
// It routes to global or project installation based on --scope.
func cmdInstall(args []string) {
	agents := parseAgentFilter(args)
	scope := parseScope(args)

	switch scope {
	case "project":
		targetDir := resolveDefaultProjectDir(".")
		if dir := parsePositionalDir(args); dir != "" {
			targetDir = dir
		}
		installProject(targetDir, agents)
	default:
		installGlobal(agents)
	}
}

// parsePositionalDir scans args for a single non-flag positional argument
// (the optional target directory), correctly skipping known flags and their
// values (--scope <value>, --agent <value>). Returns "" if none is found.
func parsePositionalDir(args []string) string {
	dir := ""
	i := 0
	for i < len(args) {
		a := args[i]
		if a == "--scope" || a == "--agent" {
			i += 2 // skip flag and its value
			continue
		}
		if !strings.HasPrefix(a, "-") {
			dir = a
		}
		i++
	}
	return dir
}

// installGlobal installs agents and skills to global user-level paths.
// Skills are always installed (shared infrastructure). Agents are gated
// by the agents filter.
func installGlobal(agents map[string]bool) {
	skillCount := 0

	// Skills → ~/.agents/skills/ (shared by Copilot and Codex)
	skillsDir := resolveGlobalDir("skills")
	if err := os.MkdirAll(skillsDir, 0755); err != nil {
		fmt.Printf("Error creating skills directory: %v\n", err)
		os.Exit(1)
	}
	seenSkillDirs := make(map[string]bool)
	if err := fs.WalkDir(skillFiles, "skills", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		content, err := fs.ReadFile(skillFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}
		relPath := filepath.ToSlash(path)
		if !strings.HasPrefix(relPath, "skills/") {
			return nil
		}
		skillRelPath := strings.TrimPrefix(relPath, "skills/")
		skillName := strings.SplitN(skillRelPath, "/", 2)[0]
		seenSkillDirs[skillName] = true

		targetPath := filepath.Join(skillsDir, skillRelPath)
		if err := os.MkdirAll(filepath.Dir(targetPath), 0755); err != nil {
			return fmt.Errorf("creating directory %s: %w", filepath.Dir(targetPath), err)
		}
		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}
		return nil
	}); err != nil {
		fmt.Printf("Error installing skills: %v\n", err)
		os.Exit(1)
	}
	skillCount = len(seenSkillDirs)
	fmt.Printf("✓ Installed %d skills to %s\n", skillCount, skillsDir)

	// Claude skills → ~/.claude/skills/
	claudeSkillsDir := resolveGlobalDir("skills-claude")
	if err := os.MkdirAll(claudeSkillsDir, 0755); err != nil {
		fmt.Printf("Error creating Claude skills directory: %v\n", err)
		os.Exit(1)
	}
	claudeSkillCount, err := installSkillTree(skillFilesClaude, "skills-claude", claudeSkillsDir)
	if err != nil {
		fmt.Printf("Error installing Claude skills: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("✓ Installed %d skills to %s\n", claudeSkillCount, claudeSkillsDir)

	// Copilot agents → ~/.copilot/agents/
	if agents["copilot"] {
		copilotAgentsDir := resolveGlobalDir("copilot")
		if err := os.MkdirAll(copilotAgentsDir, 0755); err != nil {
			fmt.Printf("Error creating Copilot agents directory: %v\n", err)
			os.Exit(1)
		}
		copilotAgentCount, err := installFlatFiles(copilotAgentFiles, "agents-copilot", copilotAgentsDir)
		if err != nil {
			fmt.Printf("Error installing Copilot agents: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d agents to %s\n", copilotAgentCount, copilotAgentsDir)
	}

	// Claude agents and commands → ~/.claude/
	if agents["claude"] {
		claudeAgentsDir := resolveGlobalDir("claude")
		if err := os.MkdirAll(claudeAgentsDir, 0755); err != nil {
			fmt.Printf("Error creating Claude agents directory: %v\n", err)
			os.Exit(1)
		}
		claudeAgentCount, err := installFlatFiles(claudeAgentFiles, "agents-claude", claudeAgentsDir)
		if err != nil {
			fmt.Printf("Error installing Claude agents: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d agents to %s\n", claudeAgentCount, claudeAgentsDir)

		claudeCommandsDir := resolveGlobalDir("commands")
		if err := os.MkdirAll(claudeCommandsDir, 0755); err != nil {
			fmt.Printf("Error creating Claude commands directory: %v\n", err)
			os.Exit(1)
		}
		claudeCommandCount, err := installFlatFiles(claudeCommandFiles, "commands-claude", claudeCommandsDir)
		if err != nil {
			fmt.Printf("Error installing Claude commands: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d commands to %s\n", claudeCommandCount, claudeCommandsDir)
	}

	// Codex agents → ~/.codex/agents/
	if agents["codex"] {
		codexAgentsDir := resolveGlobalDir("codex")
		if err := os.MkdirAll(codexAgentsDir, 0755); err != nil {
			fmt.Printf("Error creating Codex agents directory: %v\n", err)
			os.Exit(1)
		}
		codexAgentCount, err := installFlatFiles(codexAgentFiles, "agents-codex", codexAgentsDir)
		if err != nil {
			fmt.Printf("Error installing Codex agents: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d agents to %s\n", codexAgentCount, codexAgentsDir)
	}

	fmt.Println()
	fmt.Println("Extensions installed globally!")
	fmt.Println()
	fmt.Println("Get started:")
	fmt.Println("  GitHub Copilot — agents: @smaqit.release.local, @smaqit.release.pr, @smaqit.user-testing")
	fmt.Println("  GitHub Copilot — skills: available via direct invocation")
	fmt.Println("  Claude Code — agents: /smaqit.release.local, /smaqit.release.pr, /smaqit.user-testing")
	fmt.Println("  Claude Code — skills: available via direct invocation")
	fmt.Println("  Codex — agents: ask Codex to spawn smaqit.release.local, smaqit.release.pr, or smaqit.user-testing")
	fmt.Println("  Codex — skills: invoke with $, or select with /skills")
	fmt.Println()
	fmt.Println("To scaffold project tracking, run: smaqit-extensions init")
}

// installProject installs agents and skills into a project directory.
// This is the --scope project path and the legacy init behavior.
// Skills go to .agents/skills/ (Codex), Copilot agents go to .github/agents/,
// Claude goes to .claude/, Codex agents go to .codex/agents/.
func installProject(targetDir string, agents map[string]bool) {
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

	// Install the release automation workflow (never overwrite an existing one)
	githubWorkflowsDir := filepath.Join(targetDir, ".github", "workflows")
	if err := os.MkdirAll(githubWorkflowsDir, 0755); err != nil {
		fmt.Printf("Error creating workflows directory: %v\n", err)
		os.Exit(1)
	}

	workflowCount := 0
	if err := fs.WalkDir(workflowTemplateFiles, "workflow-templates", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(workflowTemplateFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		filename := filepath.Base(path)
		targetPath := filepath.Join(githubWorkflowsDir, filename)

		if _, statErr := os.Stat(targetPath); statErr != nil {
			workflowCount++
		}
		if err := writeFileIfMissing(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		return nil
	}); err != nil {
		fmt.Printf("Error installing release workflow: %v\n", err)
		os.Exit(1)
	}

	// Install Copilot agents (project: .github/agents/)
	if agents["copilot"] {
		agentCount, err := installFlatFiles(copilotAgentFiles, "agents-copilot", agentsDir)
		if err != nil {
			fmt.Printf("Error installing agents: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d agents to %s\n", agentCount, agentsDir)
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
	fmt.Printf("✓ Installed %d skills to %s\n", skillCount, skillsDir)

	// Install Claude Code agents, commands, and skills.
	if agents["claude"] {
		claudeAgentCount, err := installFlatFiles(claudeAgentFiles, "agents-claude", claudeAgentsDir)
		if err != nil {
			fmt.Printf("Error installing Claude agents: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d agents to %s\n", claudeAgentCount, claudeAgentsDir)

		claudeCommandCount, err := installFlatFiles(claudeCommandFiles, "commands-claude", claudeCommandsDir)
		if err != nil {
			fmt.Printf("Error installing Claude commands: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d commands to %s\n", claudeCommandCount, claudeCommandsDir)

		claudeSkillCount, err := installSkillTree(skillFilesClaude, "skills-claude", claudeSkillsDir)
		if err != nil {
			fmt.Printf("Error installing Claude skills: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d skills to %s\n", claudeSkillCount, claudeSkillsDir)
	}

	// Install Codex agents (project: .codex/agents/).
	// Codex skills are the same content as Copilot skills, installed to .agents/skills/.
	if agents["codex"] {
		codexAgentCount, err := installFlatFiles(codexAgentFiles, "agents-codex", codexAgentsDir)
		if err != nil {
			fmt.Printf("Error installing Codex agents: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d agents to %s\n", codexAgentCount, codexAgentsDir)

		codexSkillCount, err := installSkillTree(skillFiles, "skills", codexSkillsDir)
		if err != nil {
			fmt.Printf("Error installing Codex skills: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✓ Installed %d skills to %s\n", codexSkillCount, codexSkillsDir)
	}
	if workflowCount > 0 {
		fmt.Printf("✓ Installed %d release workflow(s) to %s\n", workflowCount, githubWorkflowsDir)
	} else {
		fmt.Printf("✓ Release workflow already present in %s (left unchanged)\n", githubWorkflowsDir)
	}
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

// cmdUninstallArgs routes uninstall to global or project paths based on --scope.
func cmdUninstallArgs(args []string) {
	scope := parseScope(args)
	agents := parseAgentFilter(args)

	switch scope {
	case "project":
		targetDir := resolveDefaultProjectDir(".")
		cmdUninstallProject(targetDir, agents)
	default:
		cmdUninstallGlobal(agents)
	}
}

// cmdUninstallGlobal removes agents and skills from global user-level paths.
func cmdUninstallGlobal(agents map[string]bool) {
	removedCount := 0

	// Skills from ~/.agents/skills/
	skillsDir := resolveGlobalDir("skills")
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

	// Claude skills from ~/.claude/skills/
	claudeSkillsDir := resolveGlobalDir("skills-claude")
	claudeSkillRemoved, err := removeSkillTree(skillFilesClaude, "skills-claude", claudeSkillsDir)
	if err != nil {
		fmt.Printf("Error enumerating Claude skills: %v\n", err)
		os.Exit(1)
	}
	removedCount += claudeSkillRemoved

	// Copilot agents
	if agents["copilot"] {
		copilotAgentsDir := resolveGlobalDir("copilot")
		copilotRemoved, err := removeFlatFiles(copilotAgentFiles, "agents-copilot", copilotAgentsDir)
		if err != nil {
			fmt.Printf("Error enumerating Copilot agents: %v\n", err)
			os.Exit(1)
		}
		removedCount += copilotRemoved
	}

	// Claude agents and commands
	if agents["claude"] {
		claudeAgentsDir := resolveGlobalDir("claude")
		claudeAgentRemoved, err := removeFlatFiles(claudeAgentFiles, "agents-claude", claudeAgentsDir)
		if err != nil {
			fmt.Printf("Error enumerating Claude agents: %v\n", err)
			os.Exit(1)
		}
		removedCount += claudeAgentRemoved

		claudeCommandsDir := resolveGlobalDir("commands")
		claudeCommandRemoved, err := removeFlatFiles(claudeCommandFiles, "commands-claude", claudeCommandsDir)
		if err != nil {
			fmt.Printf("Error enumerating Claude commands: %v\n", err)
			os.Exit(1)
		}
		removedCount += claudeCommandRemoved
	}

	// Codex agents
	if agents["codex"] {
		codexAgentsDir := resolveGlobalDir("codex")
		codexAgentRemoved, err := removeFlatFiles(codexAgentFiles, "agents-codex", codexAgentsDir)
		if err != nil {
			fmt.Printf("Error enumerating Codex agents: %v\n", err)
			os.Exit(1)
		}
		removedCount += codexAgentRemoved
	}

	if removedCount > 0 {
		fmt.Printf("✓ Removed %d extension files from global paths\n", removedCount)
		fmt.Println("Extensions uninstalled successfully!")
	} else {
		fmt.Println("No extension files found to remove from global paths")
	}
}

// cmdUninstallProject removes agents and skills from a project directory.
func cmdUninstallProject(targetDir string, agents map[string]bool) {
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")
	claudeAgentsDir := filepath.Join(targetDir, ".claude", "agents")
	claudeCommandsDir := filepath.Join(targetDir, ".claude", "commands")
	claudeSkillsDir := filepath.Join(targetDir, ".claude", "skills")
	codexAgentsDir := filepath.Join(targetDir, ".codex", "agents")
	codexSkillsDir := filepath.Join(targetDir, ".agents", "skills")

	removedCount := 0

	// Remove Copilot agents
	if agents["copilot"] {
		agentRemoved, err := removeFlatFiles(copilotAgentFiles, "agents-copilot", agentsDir)
		if err != nil {
			fmt.Printf("Error enumerating agents: %v\n", err)
			os.Exit(1)
		}
		removedCount += agentRemoved
	}

	// Remove skills (shared, always removed)
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

	// Remove Claude Code agents, commands, and skills.
	if agents["claude"] {
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
	}

	// Remove Codex agents and skills.
	if agents["codex"] {
		codexAgentRemoved, err := removeFlatFiles(codexAgentFiles, "agents-codex", codexAgentsDir)
		if err != nil {
			fmt.Printf("Error enumerating Codex agents: %v\n", err)
			os.Exit(1)
		}
		removedCount += codexAgentRemoved

		codexSkillRemoved, err := removeSkillTree(skillFiles, "skills", codexSkillsDir)
		if err != nil {
			fmt.Printf("Error enumerating Codex skills: %v\n", err)
			os.Exit(1)
		}
		removedCount += codexSkillRemoved
	}

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
	projectDir := resolveDefaultProjectDir(".")

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
		checkAndReInit(projectDir)
		return
	}
	if cmp > 0 {
		fmt.Printf("Local version (%s) is newer than latest release (%s). Nothing to do.\n", localVersion, release.TagName)
		checkAndReInit(projectDir)
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

	if err := checkAndReInitWithBinary(projectDir, currentBin); err != nil {
		fmt.Fprintf(os.Stderr, "Error re-initializing project assets: %v\n", err)
		os.Exit(1)
	}
}

// resolveDefaultProjectDir finds the project root for commands invoked without
// an explicit target. A Git worktree root takes precedence over a nested
// .smaqit directory so an accidental init from scripts/ cannot trap subsequent
// commands there. Outside Git, the nearest ancestor containing .smaqit is used;
// a new non-Git project falls back to the starting directory.
func resolveDefaultProjectDir(startDir string) string {
	absStart, err := filepath.Abs(startDir)
	if err != nil {
		return startDir
	}

	if gitRoot, ok := findAncestorWithEntry(absStart, ".git"); ok {
		return gitRoot
	}
	if smaqitRoot, ok := findAncestorWithEntry(absStart, ".smaqit"); ok {
		return smaqitRoot
	}
	return absStart
}

func findAncestorWithEntry(startDir, entryName string) (string, bool) {
	currentDir := startDir
	for {
		if _, err := os.Stat(filepath.Join(currentDir, entryName)); err == nil {
			return currentDir, true
		}

		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			return "", false
		}
		currentDir = parentDir
	}
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

// checkAndReInit refreshes the global installation and, if the current
// directory contains a .smaqit/ directory, re-scaffolds project templates.
func checkAndReInit(dir string) {
	// Always refresh the global install.
	fmt.Println("Refreshing global installation...")
	installGlobal(parseAgentFilter(nil))

	smaqitPath := filepath.Join(dir, ".smaqit")
	if _, err := os.Stat(smaqitPath); err != nil {
		fmt.Println("Run `smaqit-extensions install --scope project` to scaffold project tracking")
		return
	}

	fmt.Println("Detected .smaqit/ — re-scaffolding project templates...")
	scaffoldSmaqit(dir)
	fmt.Println("Re-scaffolded .smaqit/templates/")
}

// checkAndReInitWithBinary re-initializes in a fresh process after self-update.
func checkAndReInitWithBinary(dir, binaryPath string) error {
	// Always refresh the global install with the new binary.
	cmd := exec.Command(binaryPath, "install")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("running %s install: %w", binaryPath, err)
	}

	smaqitPath := filepath.Join(dir, ".smaqit")
	if _, err := os.Stat(smaqitPath); err != nil {
		fmt.Println("Run `smaqit-extensions install --scope project` to scaffold project tracking")
		return nil
	}

	fmt.Println("Detected .smaqit/ — re-scaffolding project templates with updated binary...")
	cmd2 := exec.Command(binaryPath, "install", "--scope", "project", dir)
	cmd2.Stdin = os.Stdin
	cmd2.Stdout = os.Stdout
	cmd2.Stderr = os.Stderr
	if err := cmd2.Run(); err != nil {
		return fmt.Errorf("running %s install --scope project: %w", binaryPath, err)
	}
	return nil
}

// scaffoldSmaqit creates the .smaqit/ directory structure and templates
// in the given project directory (create-if-absent for existing files).
func scaffoldSmaqit(targetDir string) {
	smaqitDir := filepath.Join(targetDir, ".smaqit")
	tasksDir := filepath.Join(smaqitDir, "tasks")
	historyDir := filepath.Join(smaqitDir, "history")
	userTestingDir := filepath.Join(smaqitDir, "user-testing")
	templatesDir := filepath.Join(smaqitDir, "templates")

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
		if err != nil || d.IsDir() {
			return err
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
}
