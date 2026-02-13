package main

import (
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

//go:embed prompts/*.md
var promptFiles embed.FS

//go:embed agents/*.md
var agentFiles embed.FS

//go:embed skills/*/SKILL.md
var skillFiles embed.FS

// Version is set via ldflags during build: -X main.Version=$(VERSION)
var Version = "0.4.1"

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
		}
	}

	// Default: install extensions
	targetDir := "."
	if len(os.Args) > 1 {
		targetDir = os.Args[1]
	}
	cmdInstall(targetDir)
}

func printHelp() {
	fmt.Println("smaqit-extensions - Quality-of-life workflow prompts and agents")
	fmt.Printf("Version: %s\n\n", Version)
	fmt.Println("Usage: smaqit-extensions [dir]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  smaqit-extensions          Install extensions in current directory")
	fmt.Println("  smaqit-extensions <dir>    Install extensions in specified directory")
	fmt.Println("  smaqit-extensions --help   Show this help message")
	fmt.Println("  smaqit-extensions --version Show version")
	fmt.Println("  smaqit-extensions uninstall Remove extensions from current directory")
	fmt.Println()
	fmt.Println("What gets installed:")
	fmt.Println("  .github/prompts/    - 8 workflow prompts")
	fmt.Println("  .github/agents/     - 2 utility agents")
	fmt.Println("  .github/skills/     - 8 workflow skills")
}

func cmdInstall(targetDir string) {
	// Create target directories
	promptsDir := filepath.Join(targetDir, ".github", "prompts")
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")
	smaqitDir := filepath.Join(targetDir, ".smaqit")
	tasksDir := filepath.Join(smaqitDir, "tasks")
	historyDir := filepath.Join(smaqitDir, "history")
	userTestingDir := filepath.Join(smaqitDir, "user-testing")

	if err := os.MkdirAll(promptsDir, 0755); err != nil {
		fmt.Printf("Error creating prompts directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(agentsDir, 0755); err != nil {
		fmt.Printf("Error creating agents directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(skillsDir, 0755); err != nil {
		fmt.Printf("Error creating skills directory: %v\n", err)
		os.Exit(1)
	}

	// Create .smaqit scaffolding used by prompts/agents
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

	planningPath := filepath.Join(tasksDir, "PLANNING.md")
	if err := writeFileIfMissing(planningPath, []byte(planningTemplate), 0644); err != nil {
		fmt.Printf("Error creating planning file: %v\n", err)
		os.Exit(1)
	}

	// Install prompts
	promptCount := 0
	if err := fs.WalkDir(promptFiles, "prompts", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(promptFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		filename := filepath.Base(path)
		targetPath := filepath.Join(promptsDir, filename)

		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		promptCount++
		return nil
	}); err != nil {
		fmt.Printf("Error installing prompts: %v\n", err)
		os.Exit(1)
	}

	// Install agents
	agentCount := 0
	if err := fs.WalkDir(agentFiles, "agents", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		content, err := fs.ReadFile(agentFiles, path)
		if err != nil {
			return fmt.Errorf("reading %s: %w", path, err)
		}

		filename := filepath.Base(path)
		targetPath := filepath.Join(agentsDir, filename)

		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		agentCount++
		return nil
	}); err != nil {
		fmt.Printf("Error installing agents: %v\n", err)
		os.Exit(1)
	}

	// Install skills
	skillCount := 0
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

		// Extract skill directory name and filename from path
		// path format: skills/skill-name/SKILL.md
		relPath := filepath.ToSlash(path)
		parts := strings.Split(relPath, "/")
		if len(parts) >= 3 {
			skillName := parts[1]
			filename := parts[2]
			
			skillDir := filepath.Join(skillsDir, skillName)
			if err := os.MkdirAll(skillDir, 0755); err != nil {
				return fmt.Errorf("creating skill directory %s: %w", skillDir, err)
			}

			targetPath := filepath.Join(skillDir, filename)
			if err := os.WriteFile(targetPath, content, 0644); err != nil {
				return fmt.Errorf("writing %s: %w", targetPath, err)
			}

			skillCount++
		}

		return nil
	}); err != nil {
		fmt.Printf("Error installing skills: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✓ Installed %d prompts to %s\n", promptCount, promptsDir)
	fmt.Printf("✓ Installed %d agents to %s\n", agentCount, agentsDir)
	fmt.Printf("✓ Installed %d skills to %s\n", skillCount, skillsDir)
	fmt.Println()
	fmt.Println("Extensions installed successfully!")
	fmt.Println()
	fmt.Println("Get started:")
	fmt.Println("  Use prompts in GitHub Copilot: /session.start, /task.create, etc.")
	fmt.Println("  Use agents: @smaqit.release.local, @smaqit.release.pr, @smaqit.user-testing")
	fmt.Println("  Use skills: Skills are available via prompts or direct invocation")
}

func cmdUninstall() {
	targetDir := "."
	promptsDir := filepath.Join(targetDir, ".github", "prompts")
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")

	// List files to remove
	promptFiles := []string{
		"session.start.prompt.md",
		"session.assess.prompt.md",
		"session.finish.prompt.md",
		"session.title.prompt.md",
		"task.create.prompt.md",
		"task.list.prompt.md",
		"task.complete.prompt.md",
		"test.start.prompt.md",
	}

	agentFiles := []string{
		"smaqit.release.agent.md",
		"smaqit.user-testing.agent.md",
	}

	skillDirs := []string{
		"session-start",
		"session-finish",
		"session-assess",
		"session-title",
		"task-create",
		"task-list",
		"task-complete",
		"test-start",
	}

	removedCount := 0

	// Remove prompts
	for _, file := range promptFiles {
		path := filepath.Join(promptsDir, file)
		if err := os.Remove(path); err == nil {
			removedCount++
		}
	}

	// Remove agents
	for _, file := range agentFiles {
		path := filepath.Join(agentsDir, file)
		if err := os.Remove(path); err == nil {
			removedCount++
		}
	}

	// Remove skills
	for _, dir := range skillDirs {
		skillPath := filepath.Join(skillsDir, dir)
		if err := os.RemoveAll(skillPath); err == nil {
			removedCount++
		}
	}

	if removedCount > 0 {
		fmt.Printf("✓ Removed %d extension files\n", removedCount)
		fmt.Println("Extensions uninstalled successfully!")
	} else {
		fmt.Println("No extension files found to remove")
	}
}
