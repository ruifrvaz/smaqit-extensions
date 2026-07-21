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

echo "[INFO] Installer: $binary"
echo "[INFO] Temporary project: $smoke_root"
echo "[CHECK] Installing local development build"
"$binary" init "$smoke_root"

assert_tree_matches "$repo_root/installer/agents-copilot" "$smoke_root/.github/agents" "GitHub Copilot agents"
assert_tree_matches "$repo_root/installer/skills" "$smoke_root/.github/skills" "GitHub Copilot skills"
assert_tree_matches "$repo_root/installer/agents-claude" "$smoke_root/.claude/agents" "Claude Code agents"
assert_tree_matches "$repo_root/installer/commands-claude" "$smoke_root/.claude/commands" "Claude Code commands"
assert_tree_matches "$repo_root/installer/skills-claude" "$smoke_root/.claude/skills" "Claude Code skills"
assert_tree_matches "$repo_root/installer/agents-codex" "$smoke_root/.codex/agents" "Codex agents"
assert_tree_matches "$repo_root/installer/skills-codex" "$smoke_root/.agents/skills" "Codex skills"
assert_tree_matches "$repo_root/installer/templates" "$smoke_root/.smaqit/templates" "smaqit templates"

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

if ! grep -Fq "generating \`AGENTS.md\`" "$smoke_root/.agents/skills/smaqit.project-init/SKILL.md"; then
  echo "[ERROR] Codex project-init skill was not resolved to AGENTS.md" >&2
  exit 1
fi
echo "[OK] Codex platform-specific content resolved"

echo "[CHECK] Uninstalling from temporary project"
(
  cd "$smoke_root"
  "$binary" uninstall
)

assert_empty_or_missing "$smoke_root/.github/agents" "GitHub Copilot agents"
assert_empty_or_missing "$smoke_root/.github/skills" "GitHub Copilot skills"
assert_empty_or_missing "$smoke_root/.claude/agents" "Claude Code agents"
assert_empty_or_missing "$smoke_root/.claude/commands" "Claude Code commands"
assert_empty_or_missing "$smoke_root/.claude/skills" "Claude Code skills"
assert_empty_or_missing "$smoke_root/.codex/agents" "Codex agents"
assert_empty_or_missing "$smoke_root/.agents/skills" "Codex skills"

echo "[PASS] Local installer smoke test completed successfully"
