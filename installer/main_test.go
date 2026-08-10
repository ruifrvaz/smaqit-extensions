package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const (
	helperProcessEnv = "SMAQIT_EXTENSIONS_HELPER_PROCESS"
	helperMarkerEnv  = "SMAQIT_EXTENSIONS_HELPER_MARKER"
)

func TestMain(m *testing.M) {
	if os.Getenv(helperProcessEnv) == "1" {
		markerPath := os.Getenv(helperMarkerEnv)
		payload := fmt.Sprintf("version=%s\nargs=%s\n", Version, strings.Join(os.Args[1:], " "))
		if err := os.WriteFile(markerPath, []byte(payload), 0644); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		os.Exit(0)
	}

	os.Exit(m.Run())
}

func TestCheckAndReInitWithBinaryRunsFreshProcess(t *testing.T) {
	projectDir := t.TempDir()
	if err := os.Mkdir(filepath.Join(projectDir, ".smaqit"), 0755); err != nil {
		t.Fatalf("create .smaqit directory: %v", err)
	}

	markerPath := filepath.Join(t.TempDir(), "helper-ran")
	t.Setenv(helperProcessEnv, "1")
	t.Setenv(helperMarkerEnv, markerPath)

	if err := checkAndReInitWithBinary(projectDir, os.Args[0]); err != nil {
		t.Fatalf("re-initialize with fresh process: %v", err)
	}

	payload, err := os.ReadFile(markerPath)
	if err != nil {
		t.Fatalf("fresh process did not write marker: %v", err)
	}
	wantArgs := "args=install --scope project " + projectDir
	if !strings.Contains(string(payload), wantArgs) {
		t.Fatalf("fresh process received wrong arguments: got %q, want payload containing %q", payload, wantArgs)
	}
}

func TestCheckAndReInitWithBinarySkipsNonSmaqitDirectory(t *testing.T) {
	markerPath := filepath.Join(t.TempDir(), "helper-ran")
	t.Setenv(helperProcessEnv, "1")
	t.Setenv(helperMarkerEnv, markerPath)

	if err := checkAndReInitWithBinary(t.TempDir(), os.Args[0]); err != nil {
		t.Fatalf("skip non-smaqit directory: %v", err)
	}
	payload, err := os.ReadFile(markerPath)
	if err != nil {
		t.Fatalf("fresh process did not write marker: %v", err)
	}
	if !strings.Contains(string(payload), "args=install") {
		t.Fatalf("fresh process did not run global install: got %q", payload)
	}
}

func TestResolveDefaultProjectDirPrefersGitRootOverNestedSmaqit(t *testing.T) {
	projectDir := t.TempDir()
	if err := os.Mkdir(filepath.Join(projectDir, ".git"), 0755); err != nil {
		t.Fatalf("create .git directory: %v", err)
	}
	nestedDir := filepath.Join(projectDir, "scripts", "tools")
	if err := os.MkdirAll(filepath.Join(projectDir, "scripts", ".smaqit"), 0755); err != nil {
		t.Fatalf("create accidental nested .smaqit directory: %v", err)
	}
	if err := os.MkdirAll(nestedDir, 0755); err != nil {
		t.Fatalf("create nested working directory: %v", err)
	}

	if got := resolveDefaultProjectDir(nestedDir); got != projectDir {
		t.Fatalf("resolve project root: got %q, want %q", got, projectDir)
	}
}

func TestResolveDefaultProjectDirUsesAncestorSmaqitOutsideGit(t *testing.T) {
	projectDir := t.TempDir()
	if err := os.Mkdir(filepath.Join(projectDir, ".smaqit"), 0755); err != nil {
		t.Fatalf("create .smaqit directory: %v", err)
	}
	nestedDir := filepath.Join(projectDir, "scripts", "tools")
	if err := os.MkdirAll(nestedDir, 0755); err != nil {
		t.Fatalf("create nested working directory: %v", err)
	}

	if got := resolveDefaultProjectDir(nestedDir); got != projectDir {
		t.Fatalf("resolve non-Git project root: got %q, want %q", got, projectDir)
	}
}

func TestResolveDefaultProjectDirFallsBackToStartDirectory(t *testing.T) {
	projectDir := t.TempDir()
	nestedDir := filepath.Join(projectDir, "new-project")
	if err := os.Mkdir(nestedDir, 0755); err != nil {
		t.Fatalf("create start directory: %v", err)
	}

	if got := resolveDefaultProjectDir(nestedDir); got != nestedDir {
		t.Fatalf("resolve new non-Git project: got %q, want %q", got, nestedDir)
	}
}

func TestResolveGlobalDirDefaults(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skipf("cannot resolve home directory: %v", err)
	}

	tests := []struct {
		agent string
		want  string
	}{
		{"copilot", filepath.Join(home, ".copilot", "agents")},
		{"claude", filepath.Join(home, ".claude", "agents")},
		{"codex", filepath.Join(home, ".codex", "agents")},
		{"skills", filepath.Join(home, ".agents", "skills")},
		{"skills-claude", filepath.Join(home, ".claude", "skills")},
		{"commands", filepath.Join(home, ".claude", "commands")},
	}
	for _, tt := range tests {
		t.Run(tt.agent, func(t *testing.T) {
			// Clear env overrides for this test
			t.Setenv("COPILOT_HOME", "")
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			t.Setenv("CODEX_HOME", "")
			if got := resolveGlobalDir(tt.agent); got != tt.want {
				t.Errorf("resolveGlobalDir(%q) = %q, want %q", tt.agent, got, tt.want)
			}
		})
	}
}

func TestResolveGlobalDirOverrides(t *testing.T) {
	tests := []struct {
		agent string
		env   string
		value string
		want  string
	}{
		{"copilot", "COPILOT_HOME", "/custom/copilot", "/custom/copilot/agents"},
		{"claude", "CLAUDE_CONFIG_DIR", "/custom/claude", "/custom/claude/agents"},
		{"codex", "CODEX_HOME", "/custom/codex", "/custom/codex/agents"},
	}
	for _, tt := range tests {
		t.Run(tt.agent, func(t *testing.T) {
			t.Setenv(tt.env, tt.value)
			if got := resolveGlobalDir(tt.agent); got != tt.want {
				t.Errorf("resolveGlobalDir(%q) with %s=%s = %q, want %q", tt.agent, tt.env, tt.value, got, tt.want)
			}
		})
	}
}

func TestParseAgentFilter(t *testing.T) {
	tests := []struct {
		name  string
		args  []string
		check map[string]bool // agents expected to be true
	}{
		{"default all", nil, map[string]bool{"copilot": true, "claude": true, "codex": true}},
		{"explicit all", []string{"--agent", "all"}, map[string]bool{"copilot": true, "claude": true, "codex": true}},
		{"copilot only", []string{"--agent", "copilot"}, map[string]bool{"copilot": true}},
		{"claude only", []string{"--agent", "claude"}, map[string]bool{"claude": true}},
		{"codex only", []string{"--agent", "codex"}, map[string]bool{"codex": true}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseAgentFilter(tt.args)
			for agent, want := range tt.check {
				if got[agent] != want {
					t.Errorf("parseAgentFilter(%v)[%s] = %v, want %v", tt.args, agent, got[agent], want)
				}
			}
		})
	}
}

func TestParseScope(t *testing.T) {
	if got := parseScope(nil); got != "user" {
		t.Errorf("default scope = %q, want %q", got, "user")
	}
	if got := parseScope([]string{"--scope", "project"}); got != "project" {
		t.Errorf("scope = %q, want %q", got, "project")
	}
	if got := parseScope([]string{"--scope", "user"}); got != "user" {
		t.Errorf("scope = %q, want %q", got, "user")
	}
}

func TestParsePositionalDir(t *testing.T) {
	tests := []struct {
		name string
		args []string
		want string
	}{
		{"no args", nil, ""},
		{"scope only", []string{"--scope", "project"}, ""},
		{"scope and agent", []string{"--scope", "project", "--agent", "copilot"}, ""},
		{"explicit dir after scope", []string{"--scope", "project", "/tmp/foo"}, "/tmp/foo"},
		{"explicit dir before scope", []string{"/tmp/foo", "--scope", "project"}, "/tmp/foo"},
		{"dir between flags", []string{"--agent", "copilot", "/tmp/foo", "--scope", "project"}, "/tmp/foo"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := parsePositionalDir(tt.args); got != tt.want {
				t.Errorf("parsePositionalDir(%v) = %q, want %q", tt.args, got, tt.want)
			}
		})
	}
}
