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
	wantArgs := "args=init " + projectDir
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
	if _, err := os.Stat(markerPath); !os.IsNotExist(err) {
		t.Fatalf("fresh process unexpectedly ran without .smaqit; stat error: %v", err)
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
