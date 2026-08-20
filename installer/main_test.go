package main

import (
	"fmt"
	"os"
	"os/exec"
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

	if err := checkAndReInitWithBinary(projectDir, os.Args[0], false); err != nil {
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
	// Regression (task 033): update's reinit must never request a
	// project-scoped agent/skill install.
	if strings.Contains(string(payload), "--scope project") {
		t.Fatalf("fresh process was asked for a project-scoped install: %q", payload)
	}
	// Regression (task 035): the confidentiality hook is opt-in — an update
	// with no --with-hooks flag must never request it either.
	if strings.Contains(string(payload), "--with-hooks") {
		t.Fatalf("fresh process was asked for the hook without opting in: %q", payload)
	}
}

// Regression (task 035): withHooks must thread through to the re-exec'd
// subprocess's own --with-hooks flag, not just this process's install.
func TestCheckAndReInitWithBinaryForwardsWithHooksFlag(t *testing.T) {
	projectDir := t.TempDir()
	if err := os.Mkdir(filepath.Join(projectDir, ".smaqit"), 0755); err != nil {
		t.Fatalf("create .smaqit directory: %v", err)
	}

	markerPath := filepath.Join(t.TempDir(), "helper-ran")
	t.Setenv(helperProcessEnv, "1")
	t.Setenv(helperMarkerEnv, markerPath)

	if err := checkAndReInitWithBinary(projectDir, os.Args[0], true); err != nil {
		t.Fatalf("re-initialize with fresh process: %v", err)
	}

	payload, err := os.ReadFile(markerPath)
	if err != nil {
		t.Fatalf("fresh process did not write marker: %v", err)
	}
	wantArgs := "args=init " + projectDir + " --with-hooks"
	if !strings.Contains(string(payload), wantArgs) {
		t.Fatalf("fresh process did not receive --with-hooks: got %q, want payload containing %q", payload, wantArgs)
	}
}

// Regression (task 033): the scaffold path shared by `init` and `update`'s
// reinit must create project tracking only — never the project-scoped
// agent/skill mirror trees that `install --scope project` opts into.
// Regression (task 035): the confidentiality hook must never appear unless
// withHooks is explicitly true — it is opt-in, not part of default scaffolding.
func TestScaffoldProjectCreatesOnlyProjectTrackingPaths(t *testing.T) {
	projectDir := t.TempDir()
	scaffoldProject(projectDir, false)

	for _, want := range []string{
		filepath.Join(".smaqit", "tasks"),
		filepath.Join(".smaqit", "history"),
		filepath.Join(".smaqit", "user-testing"),
		filepath.Join(".github", "workflows"),
	} {
		if _, err := os.Stat(filepath.Join(projectDir, want)); err != nil {
			t.Errorf("expected scaffolded path %s: %v", want, err)
		}
	}

	for _, forbidden := range []string{
		".agents",
		".claude",
		filepath.Join(".codex"),
		filepath.Join(".github", "agents"),
		filepath.Join(".github", "skills"),
		filepath.Join(".smaqit", "hooks"),
	} {
		if _, err := os.Stat(filepath.Join(projectDir, forbidden)); err == nil {
			t.Errorf("scaffolding created project-scoped mirror path %s", forbidden)
		}
	}
}

// Regression (task 035): scaffoldProject(dir, true) is the opt-in path —
// confirms the hook actually gets installed when explicitly requested,
// complementing the opt-out assertion in
// TestScaffoldProjectCreatesOnlyProjectTrackingPaths.
func TestScaffoldProjectWithHooksInstallsConfidentialityHook(t *testing.T) {
	projectDir := t.TempDir()
	initGitRepo(t, projectDir)

	scaffoldProject(projectDir, true)

	if _, err := os.Stat(filepath.Join(projectDir, ".smaqit", "hooks", "pre-commit-confidentiality.sh")); err != nil {
		t.Errorf("expected --with-hooks to install the confidentiality scan script: %v", err)
	}
}

func TestCheckAndReInitWithBinarySkipsNonSmaqitDirectory(t *testing.T) {
	markerPath := filepath.Join(t.TempDir(), "helper-ran")
	t.Setenv(helperProcessEnv, "1")
	t.Setenv(helperMarkerEnv, markerPath)

	if err := checkAndReInitWithBinary(t.TempDir(), os.Args[0], false); err != nil {
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

func TestParseWithHooks(t *testing.T) {
	if got := parseWithHooks(nil); got != false {
		t.Errorf("default with-hooks = %v, want %v", got, false)
	}
	if got := parseWithHooks([]string{"--with-hooks"}); got != true {
		t.Errorf("with-hooks = %v, want %v", got, true)
	}
	if got := parseWithHooks([]string{"--scope", "project", "--with-hooks"}); got != true {
		t.Errorf("with-hooks alongside other flags = %v, want %v", got, true)
	}
	if got := parseWithHooks([]string{"--scope", "project"}); got != false {
		t.Errorf("with-hooks absent = %v, want %v", got, false)
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
		{"with-hooks does not consume the dir slot", []string{"--scope", "project", "--with-hooks", "/tmp/foo"}, "/tmp/foo"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := parsePositionalDir(tt.args); got != tt.want {
				t.Errorf("parsePositionalDir(%v) = %q, want %q", tt.args, got, tt.want)
			}
		})
	}
}

// initGitRepo creates a real Git repository at dir. installConfidentialityHook
// is a no-op against anything git itself doesn't recognize as a work tree
// (see TestScaffoldProjectCreatesOnlyProjectTrackingPaths, which uses a plain
// t.TempDir() and correctly gets no hook files) — these tests need the real
// thing to exercise the hook-wiring logic at all.
func initGitRepo(t *testing.T, dir string) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	if out, err := exec.Command("git", "-C", dir, "init", "-q").CombinedOutput(); err != nil {
		t.Fatalf("git init: %v: %s", err, out)
	}
	if out, err := exec.Command("git", "-C", dir, "config", "user.email", "test@example.com").CombinedOutput(); err != nil {
		t.Fatalf("git config user.email: %v: %s", err, out)
	}
	if out, err := exec.Command("git", "-C", dir, "config", "user.name", "test").CombinedOutput(); err != nil {
		t.Fatalf("git config user.name: %v: %s", err, out)
	}
}

// Regression (task 035): a fresh install must produce the force-overwritten
// script, the seed-once ignore list, and a managed block wired into
// .git/hooks/pre-commit — the three artifacts installConfidentialityHook
// documents.
func TestInstallConfidentialityHookFreshInstall(t *testing.T) {
	dir := t.TempDir()
	initGitRepo(t, dir)

	installConfidentialityHook(dir)

	scriptPath := filepath.Join(dir, ".smaqit", "hooks", "pre-commit-confidentiality.sh")
	info, err := os.Stat(scriptPath)
	if err != nil {
		t.Fatalf("expected confidentiality scan script: %v", err)
	}
	if info.Mode()&0111 == 0 {
		t.Errorf("expected confidentiality scan script to be executable, got mode %v", info.Mode())
	}

	ignorePath := filepath.Join(dir, ".smaqit", "hooks", "confidentiality-scan-ignore")
	if _, err := os.Stat(ignorePath); err != nil {
		t.Fatalf("expected confidentiality-scan-ignore: %v", err)
	}

	hookPath := filepath.Join(dir, ".git", "hooks", "pre-commit")
	hookContent, err := os.ReadFile(hookPath)
	if err != nil {
		t.Fatalf("expected .git/hooks/pre-commit: %v", err)
	}
	if !strings.Contains(string(hookContent), confidentialityHookMarkerBegin) {
		t.Errorf(".git/hooks/pre-commit missing managed block begin marker: %q", hookContent)
	}
	if !strings.Contains(string(hookContent), ".smaqit/hooks/pre-commit-confidentiality.sh") {
		t.Errorf(".git/hooks/pre-commit does not dispatch to the confidentiality script: %q", hookContent)
	}
}

// Regression (task 035): reinstalling must force-overwrite the detection
// script (so pattern/bug fixes propagate) but never touch a user's edits to
// the exclude-list (seeded once via writeFileIfMissing).
func TestInstallConfidentialityHookReinstallPreservesIgnoreList(t *testing.T) {
	dir := t.TempDir()
	initGitRepo(t, dir)

	installConfidentialityHook(dir)

	scriptPath := filepath.Join(dir, ".smaqit", "hooks", "pre-commit-confidentiality.sh")
	if err := os.WriteFile(scriptPath, []byte("#!/usr/bin/env bash\n# stale pre-fix content\n"), 0755); err != nil {
		t.Fatalf("simulate stale script: %v", err)
	}

	ignorePath := filepath.Join(dir, ".smaqit", "hooks", "confidentiality-scan-ignore")
	userEdit := "\n# user-added exclusion\nfixtures/my-secret.pem\n"
	existingIgnore, err := os.ReadFile(ignorePath)
	if err != nil {
		t.Fatalf("read seeded ignore file: %v", err)
	}
	if err := os.WriteFile(ignorePath, append(existingIgnore, []byte(userEdit)...), 0644); err != nil {
		t.Fatalf("simulate user edit: %v", err)
	}

	installConfidentialityHook(dir)

	scriptContent, err := os.ReadFile(scriptPath)
	if err != nil {
		t.Fatalf("read script after reinstall: %v", err)
	}
	if strings.Contains(string(scriptContent), "stale pre-fix content") {
		t.Errorf("expected reinstall to force-overwrite the script, stale content survived")
	}

	ignoreContent, err := os.ReadFile(ignorePath)
	if err != nil {
		t.Fatalf("read ignore file after reinstall: %v", err)
	}
	if !strings.Contains(string(ignoreContent), "fixtures/my-secret.pem") {
		t.Errorf("expected reinstall to preserve the user's ignore-list edit, got: %q", ignoreContent)
	}
}

// Regression (task 035): an existing .git/hooks/pre-commit from another tool
// must never be clobbered — the managed block is appended after it.
func TestInstallConfidentialityHookAppendsToExistingPreCommitHook(t *testing.T) {
	dir := t.TempDir()
	initGitRepo(t, dir)

	hooksDir := filepath.Join(dir, ".git", "hooks")
	if err := os.MkdirAll(hooksDir, 0755); err != nil {
		t.Fatalf("create hooks dir: %v", err)
	}
	hookPath := filepath.Join(hooksDir, "pre-commit")
	foreignContent := "#!/usr/bin/env bash\n# some-other-tool's own hook\necho some-other-tool-ran\n"
	if err := os.WriteFile(hookPath, []byte(foreignContent), 0755); err != nil {
		t.Fatalf("seed foreign hook: %v", err)
	}

	installConfidentialityHook(dir)

	got, err := os.ReadFile(hookPath)
	if err != nil {
		t.Fatalf("read hook after install: %v", err)
	}
	if !strings.Contains(string(got), "some-other-tool-ran") {
		t.Errorf("expected foreign hook content to survive, got: %q", got)
	}
	if !strings.Contains(string(got), confidentialityHookMarkerBegin) {
		t.Errorf("expected managed block to be appended, got: %q", got)
	}
	if strings.Index(string(got), "some-other-tool-ran") > strings.Index(string(got), confidentialityHookMarkerBegin) {
		t.Errorf("expected managed block to be appended after the foreign content, not before: %q", got)
	}
}

// Regression (task 035): reinstalling against a repo that already has the
// managed block must replace it in place (picking up a changed block on
// upgrade), never duplicate it via a second append.
func TestInstallConfidentialityHookIdempotentReplace(t *testing.T) {
	dir := t.TempDir()
	initGitRepo(t, dir)

	installConfidentialityHook(dir)
	installConfidentialityHook(dir)

	hookPath := filepath.Join(dir, ".git", "hooks", "pre-commit")
	got, err := os.ReadFile(hookPath)
	if err != nil {
		t.Fatalf("read hook after reinstall: %v", err)
	}
	if n := strings.Count(string(got), confidentialityHookMarkerBegin); n != 1 {
		t.Errorf("expected exactly one managed block after reinstall, found %d: %q", n, got)
	}

	// Simulate an older block version, then confirm reinstall replaces it in
	// place rather than skipping (which would leave the stale block behind).
	stale := strings.Replace(string(got), confidentialityHookBlock, confidentialityHookMarkerBegin+"\necho stale-block-version\n"+confidentialityHookMarkerEnd+"\n", 1)
	if err := os.WriteFile(hookPath, []byte(stale), 0755); err != nil {
		t.Fatalf("simulate stale block: %v", err)
	}

	installConfidentialityHook(dir)

	got, err = os.ReadFile(hookPath)
	if err != nil {
		t.Fatalf("read hook after replace: %v", err)
	}
	if strings.Contains(string(got), "stale-block-version") {
		t.Errorf("expected reinstall to replace the stale managed block, it survived: %q", got)
	}
	if n := strings.Count(string(got), confidentialityHookMarkerBegin); n != 1 {
		t.Errorf("expected exactly one managed block after replace, found %d: %q", n, got)
	}
}

// Regression (task 035): the installed hook actually blocks a staged
// credential-shaped secret, and a path listed in the exclude-list does not.
func TestConfidentialityHookScriptBlocksPlantedCredentialButRespectsIgnoreList(t *testing.T) {
	dir := t.TempDir()
	initGitRepo(t, dir)
	installConfidentialityHook(dir)

	runHook := func() ([]byte, error) {
		cmd := exec.Command(filepath.Join(dir, ".git", "hooks", "pre-commit"))
		cmd.Dir = dir
		return cmd.CombinedOutput()
	}

	secretPath := filepath.Join(dir, "secret.txt")
	if err := os.WriteFile(secretPath, []byte("AKIAABCDEFGHIJKLMNOP\n"), 0644); err != nil {
		t.Fatalf("write planted secret: %v", err)
	}
	if out, err := exec.Command("git", "-C", dir, "add", "secret.txt").CombinedOutput(); err != nil {
		t.Fatalf("git add secret.txt: %v: %s", err, out)
	}

	if out, err := runHook(); err == nil {
		t.Errorf("expected the hook to block a staged AWS-key-shaped credential, it exited 0: %s", out)
	}

	if out, err := exec.Command("git", "-C", dir, "reset", "secret.txt").CombinedOutput(); err != nil {
		t.Fatalf("git reset secret.txt: %v: %s", err, out)
	}

	ignorePath := filepath.Join(dir, ".smaqit", "hooks", "confidentiality-scan-ignore")
	existingIgnore, err := os.ReadFile(ignorePath)
	if err != nil {
		t.Fatalf("read ignore file: %v", err)
	}
	if err := os.WriteFile(ignorePath, append(existingIgnore, []byte("\nsecret.txt\n")...), 0644); err != nil {
		t.Fatalf("add secret.txt to ignore list: %v", err)
	}
	if out, err := exec.Command("git", "-C", dir, "add", "secret.txt").CombinedOutput(); err != nil {
		t.Fatalf("git add secret.txt (second time): %v: %s", err, out)
	}

	if out, err := runHook(); err != nil {
		t.Errorf("expected the hook to allow an excluded path, it blocked: %v: %s", err, out)
	}
}

// Regression (task 035): delta-scoped means exactly what it says — a
// violation already committed to the tree, with no staged change touching
// it, must never block an unrelated commit.
func TestConfidentialityHookScriptIsDeltaScoped(t *testing.T) {
	dir := t.TempDir()
	initGitRepo(t, dir)
	installConfidentialityHook(dir)

	preexistingPath := filepath.Join(dir, "preexisting-secret.txt")
	if err := os.WriteFile(preexistingPath, []byte("AKIAABCDEFGHIJKLMNOP\n"), 0644); err != nil {
		t.Fatalf("write pre-existing secret: %v", err)
	}
	if out, err := exec.Command("git", "-C", dir, "add", "preexisting-secret.txt").CombinedOutput(); err != nil {
		t.Fatalf("git add preexisting-secret.txt: %v: %s", err, out)
	}
	commitCmd := exec.Command("git", "-C", dir, "commit", "--no-verify", "-q", "-m", "preexisting violation, committed on purpose for test setup")
	if out, err := commitCmd.CombinedOutput(); err != nil {
		t.Fatalf("commit pre-existing secret: %v: %s", err, out)
	}

	unrelatedPath := filepath.Join(dir, "unrelated.txt")
	if err := os.WriteFile(unrelatedPath, []byte("unrelated change\n"), 0644); err != nil {
		t.Fatalf("write unrelated file: %v", err)
	}
	if out, err := exec.Command("git", "-C", dir, "add", "unrelated.txt").CombinedOutput(); err != nil {
		t.Fatalf("git add unrelated.txt: %v: %s", err, out)
	}

	cmd := exec.Command(filepath.Join(dir, ".git", "hooks", "pre-commit"))
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Errorf("expected an unrelated staged change not to be blocked by a pre-existing, unstaged violation: %v: %s", err, out)
	}
}
