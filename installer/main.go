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

//go:embed agents/*.md
var agentFiles embed.FS

//go:embed skills/*
var skillFiles embed.FS

// Version is set via ldflags during build: -X main.Version=$(VERSION)
var Version = "0.4.2"

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
	fmt.Println("  smaqit-extensions uninstall      Remove extensions from current directory")
	fmt.Println("  smaqit-extensions version        Show version")
	fmt.Println("  smaqit-extensions --help         Show this help message")
	fmt.Println()
	fmt.Println("What gets installed:")
	fmt.Println("  .github/agents/     - 3 utility agents")
	fmt.Println("  .github/skills/     - 16 workflow skills")
}

func cmdInstall(targetDir string) {
	// Create target directories
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")
	smaqitDir := filepath.Join(targetDir, ".smaqit")
	tasksDir := filepath.Join(smaqitDir, "tasks")
	historyDir := filepath.Join(smaqitDir, "history")
	userTestingDir := filepath.Join(smaqitDir, "user-testing")

	if err := os.MkdirAll(agentsDir, 0755); err != nil {
		fmt.Printf("Error creating agents directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(skillsDir, 0755); err != nil {
		fmt.Printf("Error creating skills directory: %v\n", err)
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

	planningPath := filepath.Join(tasksDir, "PLANNING.md")
	if err := writeFileIfMissing(planningPath, []byte(planningTemplate), 0644); err != nil {
		fmt.Printf("Error creating planning file: %v\n", err)
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

		// Extract relative path from skills/ root
		// path format: skills/skill-name/SKILL.md or skills/skill-name/references/RULES.md
		relPath := filepath.ToSlash(path)
		if !strings.HasPrefix(relPath, "skills/") {
			return nil
		}

		// Remove "skills/" prefix to get skill-relative path
		skillRelPath := strings.TrimPrefix(relPath, "skills/")

		// Create target path
		targetPath := filepath.Join(skillsDir, skillRelPath)
		targetDir := filepath.Dir(targetPath)

		if err := os.MkdirAll(targetDir, 0755); err != nil {
			return fmt.Errorf("creating directory %s: %w", targetDir, err)
		}

		if err := os.WriteFile(targetPath, content, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", targetPath, err)
		}

		skillCount++

		return nil
	}); err != nil {
		fmt.Printf("Error installing skills: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✓ Installed %d agents to %s\n", agentCount, agentsDir)
	fmt.Printf("✓ Installed %d skills to %s\n", skillCount, skillsDir)
	fmt.Println()
	fmt.Println("Extensions installed successfully!")
	fmt.Println()
	fmt.Println("Get started:")
	fmt.Println("  Use agents: @smaqit.release.local, @smaqit.release.pr, @smaqit.user-testing")
	fmt.Println("  Use skills: Skills are available via direct invocation in GitHub Copilot")
}

func cmdUninstall() {
	targetDir := "."
	agentsDir := filepath.Join(targetDir, ".github", "agents")
	skillsDir := filepath.Join(targetDir, ".github", "skills")

	removedCount := 0

	// Remove agents: discover from embedded FS
	if err := fs.WalkDir(agentFiles, "agents", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		targetPath := filepath.Join(agentsDir, filepath.Base(path))
		if removeErr := os.Remove(targetPath); removeErr == nil {
			removedCount++
		}
		return nil
	}); err != nil {
		fmt.Printf("Error enumerating agents: %v\n", err)
		os.Exit(1)
	}

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

	if removedCount > 0 {
		fmt.Printf("✓ Removed %d extension files\n", removedCount)
		fmt.Println("Extensions uninstalled successfully!")
	} else {
		fmt.Println("No extension files found to remove")
	}
}
