#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
binary_input="${1:-$repo_root/installer/dist/smaqit-extensions}"

if [[ "$binary_input" = /* ]]; then
  binary="$binary_input"
else
  binary="$(cd "$(dirname "$binary_input")" && pwd)/$(basename "$binary_input")"
fi

if [[ ! -x "$binary" ]]; then
  echo "[ERROR] Installer binary is missing or not executable: $binary" >&2
  echo "[ERROR] Build it first with: make -C installer build" >&2
  exit 1
fi

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-extensions-smoke.XXXXXX")"

cleanup() {
  if [[ "${KEEP_SMOKE_DIR:-0}" == "1" ]]; then
    echo "[INFO] Preserving smoke-test directory: $smoke_root"
    return
  fi

  case "$smoke_root" in
    */smaqit-extensions-smoke.*)
      rm -rf -- "$smoke_root"
      echo "[INFO] Removed temporary smoke-test directory: $smoke_root"
      ;;
    *)
      echo "[WARN] Refusing to remove unexpected smoke-test path: $smoke_root" >&2
      ;;
  esac
}
trap cleanup EXIT

assert_tree_matches() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if ! diff -qr "$expected" "$actual"; then
    echo "[ERROR] Installed $label differs from generated staging artifacts" >&2
    exit 1
  fi
  echo "[OK] $label matches generated staging artifacts"
}

assert_empty_or_missing() {
  local path="$1"
  local label="$2"

  if [[ -d "$path" ]] && [[ -n "$(find "$path" -mindepth 1 -print -quit)" ]]; then
    echo "[ERROR] $label was not fully removed: $path" >&2
    exit 1
  fi
  echo "[OK] $label removed"
}

assert_contains() {
  local path="$1"
  local expected="$2"
  local label="$3"

  if ! grep -Fq "$expected" "$path"; then
    echo "[ERROR] $label is missing expected content: $expected" >&2
    exit 1
  fi
  echo "[OK] $label contains expected content"
}

echo "[INFO] Installer: $binary"
echo "[INFO] Temporary project: $smoke_root"
echo "[CHECK] Installing local development build from a nested working directory"
mkdir -p "$smoke_root/.git" "$smoke_root/scripts/.smaqit"
touch "$smoke_root/scripts/.smaqit/accidental-nested-project"
(
  cd "$smoke_root/scripts"
  "$binary" init
)

assert_empty_or_missing "$smoke_root/scripts/.github" "nested GitHub target"
assert_empty_or_missing "$smoke_root/scripts/.claude" "nested Claude target"
assert_empty_or_missing "$smoke_root/scripts/.codex" "nested Codex target"
assert_empty_or_missing "$smoke_root/scripts/.agents" "nested shared-agent target"
echo "[OK] Nested init resolved the Git project root"

assert_tree_matches "$repo_root/installer/agents-copilot" "$smoke_root/.github/agents" "GitHub Copilot agents"
assert_tree_matches "$repo_root/installer/skills" "$smoke_root/.github/skills" "GitHub Copilot skills"
assert_tree_matches "$repo_root/installer/agents-claude" "$smoke_root/.claude/agents" "Claude Code agents"
assert_tree_matches "$repo_root/installer/commands-claude" "$smoke_root/.claude/commands" "Claude Code commands"
assert_tree_matches "$repo_root/installer/skills-claude" "$smoke_root/.claude/skills" "Claude Code skills"
assert_tree_matches "$repo_root/installer/agents-codex" "$smoke_root/.codex/agents" "Codex agents"
assert_tree_matches "$repo_root/installer/skills-codex" "$smoke_root/.agents/skills" "Codex skills"
assert_tree_matches "$repo_root/installer/templates" "$smoke_root/.smaqit/templates" "smaqit templates"
assert_tree_matches "$repo_root/installer/workflow-templates" "$smoke_root/.github/workflows" "release automation workflow"

echo "[CHECK] Root .claude/ dogfooding mirror matches canonical (this repo's own copy, not the temp project's)"
assert_tree_matches "$repo_root/installer/agents-claude" "$repo_root/.claude/agents" "root .claude agents (dogfooding mirror)"
assert_tree_matches "$repo_root/installer/commands-claude" "$repo_root/.claude/commands" "root .claude commands (dogfooding mirror)"
assert_tree_matches "$repo_root/installer/skills-claude" "$repo_root/.claude/skills" "root .claude skills (dogfooding mirror)"

echo "[CHECK] Re-running init preserves a customized release workflow"
echo "# locally customized — must survive re-init" >> "$smoke_root/.github/workflows/post-merge-release.yml"
(
  cd "$smoke_root/scripts"
  "$binary" init
)
assert_contains "$smoke_root/.github/workflows/post-merge-release.yml" "locally customized — must survive re-init" "release workflow create-if-absent idempotency"

desktop_ssh_guidance="Desktop Linux SSH Agent Recovery"
assert_contains "$smoke_root/.github/agents/smaqit.release.local.agent.md" "$desktop_ssh_guidance" "Copilot local-release agent desktop SSH recovery"
assert_contains "$smoke_root/.claude/agents/smaqit.release.local.md" "$desktop_ssh_guidance" "Claude local-release agent desktop SSH recovery"
assert_contains "$smoke_root/.codex/agents/smaqit.release.local.toml" "$desktop_ssh_guidance" "Codex local-release agent desktop SSH recovery"
assert_contains "$smoke_root/.claude/skills/smaqit.release-git-local/SKILL.md" "$desktop_ssh_guidance" "Claude local-release skill desktop SSH recovery"
assert_contains "$smoke_root/.smaqit/templates/copilot-instructions.template.md" "$desktop_ssh_guidance" "Claude project-instructions template desktop SSH recovery"
assert_contains "$smoke_root/.claude/agents/smaqit.release.local.md" 'gpgconf --list-dirs agent-ssh-socket' "Claude agent GnuPG socket discovery"
assert_contains "$smoke_root/.claude/agents/smaqit.release.local.md" 'keyring/ssh' "Claude agent GNOME Keyring socket discovery"

if grep -R -E '(^|[[:space:]])export SSH_AUTH_SOCK=' \
  "$smoke_root/.github/agents/smaqit.release.local.agent.md" \
  "$smoke_root/.claude/agents/smaqit.release.local.md" \
  "$smoke_root/.codex/agents/smaqit.release.local.toml" \
  "$smoke_root/.github/skills/smaqit.release-git-local" \
  "$smoke_root/.claude/skills/smaqit.release-git-local" \
  "$smoke_root/.agents/skills/smaqit.release-git-local" \
  "$smoke_root/.smaqit/templates/copilot-instructions.template.md"; then
  echo "[ERROR] Desktop Linux SSH recovery must not persist SSH_AUTH_SOCK" >&2
  exit 1
fi
echo "[OK] Desktop Linux SSH recovery remains command-scoped"

if [[ ! -f "$smoke_root/.smaqit/tasks/PLANNING.md" ]]; then
  echo "[ERROR] Missing .smaqit/tasks/PLANNING.md" >&2
  exit 1
fi
echo "[OK] smaqit project scaffolding installed"

python3 - "$smoke_root" "$repo_root" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
repo = pathlib.Path(sys.argv[2])
agent_paths = sorted((root / ".codex" / "agents").glob("smaqit.*.toml"))
if len(agent_paths) != 3:
    raise SystemExit(f"expected 3 Codex agents, found {len(agent_paths)}")

required = {"name", "description", "developer_instructions"}
for path in agent_paths:
    data = tomllib.loads(path.read_text())
    missing = required - data.keys()
    if missing:
        raise SystemExit(f"{path}: missing required fields: {sorted(missing)}")

expected_skills = {path.name for path in (repo / "skills").iterdir() if path.is_dir()}
installed_skills = {path.parent.name for path in (root / ".agents" / "skills").glob("*/SKILL.md")}
if installed_skills != expected_skills:
    missing = sorted(expected_skills - installed_skills)
    extra = sorted(installed_skills - expected_skills)
    raise SystemExit(f"Codex skill mismatch; missing={missing}, extra={extra}")

print("[OK] Codex agent TOML and skill counts validated")
PY

if grep -R -E 'report_progress|\.github/skills|\.claude/skills' "$smoke_root/.codex/agents"; then
  echo "[ERROR] Platform-incompatible content found in Codex agents" >&2
  exit 1
fi

if grep -R -E '\[SMAQIT_SKILLS_DIR\]|\{\{(INSTRUCTIONS_FILE|PUSH_STEP|PUSH_METHOD_SUMMARY|PUSH_CREDENTIAL_SOURCE|PUSH_FAILURE_ROW)\}\}' "$smoke_root/.agents/skills"; then
  echo "[ERROR] Unresolved Codex build-time placeholder found" >&2
  exit 1
fi

project_init_copilot="$smoke_root/.github/skills/smaqit.project-init/SKILL.md"
project_init_claude="$smoke_root/.claude/skills/smaqit.project-init/SKILL.md"
project_init_codex="$smoke_root/.agents/skills/smaqit.project-init/SKILL.md"

assert_contains "$project_init_codex" 'AGENTS.md` — canonical shared project instructions' "project-init canonical AGENTS contract"
assert_contains "$project_init_codex" 'Claude-only instructions' "project-init Claude import contract"
assert_contains "$project_init_codex" 'relative symlink to' "project-init Copilot symlink contract"
assert_contains "$project_init_codex" '../AGENTS.md' "project-init Copilot symlink target"
assert_contains "$project_init_codex" 'Do not stop merely because one or more instruction files already exist.' "project-init existing-file migration contract"
assert_contains "$project_init_codex" 'Semantic merging must be performed through model inference' "project-init inferential merge contract"

if grep -Fq 'Aborting to avoid overwriting' "$project_init_codex" ||
  grep -Fq '**Never overwrite**' "$project_init_codex"; then
  echo "[ERROR] Legacy project-init existing-file abort behavior remains" >&2
  exit 1
fi

if ! cmp -s "$project_init_copilot" "$project_init_claude" ||
  ! cmp -s "$project_init_copilot" "$project_init_codex"; then
  echo "[ERROR] Project-init synchronization contract differs across platforms" >&2
  exit 1
fi
echo "[OK] Project-init synchronization contract is shared across platforms"

echo "[CHECK] Uninstalling from temporary project"
(
  cd "$smoke_root/scripts"
  "$binary" uninstall
)

assert_empty_or_missing "$smoke_root/.github/agents" "GitHub Copilot agents"
assert_empty_or_missing "$smoke_root/.github/skills" "GitHub Copilot skills"
assert_empty_or_missing "$smoke_root/.claude/agents" "Claude Code agents"
assert_empty_or_missing "$smoke_root/.claude/commands" "Claude Code commands"
assert_empty_or_missing "$smoke_root/.claude/skills" "Claude Code skills"
assert_empty_or_missing "$smoke_root/.codex/agents" "Codex agents"
assert_empty_or_missing "$smoke_root/.agents/skills" "Codex skills"
echo "[OK] Nested uninstall resolved the Git project root"

echo "[PASS] Local installer smoke test completed successfully"
