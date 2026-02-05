package main

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

//go:embed prompts/*.md
var promptFiles embed.FS

//go:embed agents/*.md
var agentFiles embed.FS

// Version is set via ldflags during build: -X main.Version=$(VERSION)
var Version = "0.1.0"

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
	fmt.Println("smaqit-extensions - Quality-of-life extensions for smaqit")
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
}

func cmdInstall(targetDir string) {
	// Create target directories
	promptsDir := filepath.Join(targetDir, ".github", "prompts")
	agentsDir := filepath.Join(targetDir, ".github", "agents")

	if err := os.MkdirAll(promptsDir, 0755); err != nil {
		fmt.Printf("Error creating prompts directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(agentsDir, 0755); err != nil {
		fmt.Printf("Error creating agents directory: %v\n", err)
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

	fmt.Printf("✓ Installed %d prompts to %s\n", promptCount, promptsDir)
	fmt.Printf("✓ Installed %d agents to %s\n", agentCount, agentsDir)
	fmt.Println()
	fmt.Println("Extensions installed successfully!")
	fmt.Println()
	fmt.Println("Get started:")
	fmt.Println("  Use prompts in GitHub Copilot: /session.start, /task.create, etc.")
	fmt.Println("  Use agents: @smaqit.release, @smaqit.user-testing")
}

func cmdUninstall() {
	targetDir := "."
	promptsDir := filepath.Join(targetDir, ".github", "prompts")
	agentsDir := filepath.Join(targetDir, ".github", "agents")

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

	if removedCount > 0 {
		fmt.Printf("✓ Removed %d extension files\n", removedCount)
		fmt.Println("Extensions uninstalled successfully!")
	} else {
		fmt.Println("No extension files found to remove")
	}
}
