#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Optional: Migrate VS Code chat sessions
# ==============================================================================
# When switching from a single-folder workspace to a multi-root
# `.code-workspace`, VS Code creates a new storage entry and existing chat
# sessions do not carry over automatically. This script delta-copies chat
# transcripts and editing sessions, then merges relevant state.vscdb keys.
#
# Usage: bash 8_migrate_sessions.sh
# Trigger: worktree.migrate-sessions
#
# Requirements:
#   - VS Code must be closed
#   - git, jq, sqlite3, and python3 on PATH
#   - VSCODE_STORAGE may override workspaceStorage auto-detection
# ==============================================================================
set -euo pipefail

green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*"; }

command -v git >/dev/null 2>&1 || { red "✗ git is required."; exit 1; }
command -v jq >/dev/null 2>&1 || { red "✗ jq is required."; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { red "✗ sqlite3 is required."; exit 1; }
command -v python3 >/dev/null 2>&1 || { red "✗ python3 is required."; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$REPO_ROOT")}"

# Detect the actual workspace file in the repository root.
shopt -s nullglob
workspace_files=("$REPO_ROOT"/*.code-workspace)
shopt -u nullglob
if [ "${#workspace_files[@]}" -eq 0 ]; then
  red "✗ No .code-workspace file found in ${REPO_ROOT}."
  echo "   Create one first, then retry."
  exit 1
fi
WORKSPACE_FILE="$(basename "${workspace_files[0]}")"

# Support explicit injection for testing and non-default installations, then
# check the default stable VS Code locations for Linux, macOS, and Git Bash.
if [ -z "${VSCODE_STORAGE:-}" ]; then
  candidates=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/workspaceStorage"
    "$HOME/Library/Application Support/Code/User/workspaceStorage"
  )
  if [ -n "${APPDATA:-}" ]; then
    candidates+=("$APPDATA/Code/User/workspaceStorage")
  fi

  VSCODE_STORAGE=""
  for candidate in "${candidates[@]}"; do
    if [ -d "$candidate" ]; then
      VSCODE_STORAGE="$candidate"
      break
    fi
  done
fi

if [ -z "${VSCODE_STORAGE:-}" ] || [ ! -d "$VSCODE_STORAGE" ]; then
  red "✗ VS Code workspace storage directory not found."
  echo "   Set VSCODE_STORAGE to the correct workspaceStorage directory and retry."
  exit 1
fi

# VS Code must be closed before its SQLite state is modified.
if command -v pgrep >/dev/null 2>&1 && pgrep -x code >/dev/null 2>&1; then
  main_pid=""
  while IFS= read -r pid; do
    if ps -p "$pid" -o args= 2>/dev/null | grep -qv -- '--type='; then
      main_pid="$pid"
      break
    fi
  done < <(pgrep -x code)

  if [ -n "$main_pid" ]; then
    yellow "⚡ VS Code main process is running (PID $main_pid)."
    echo "   Close VS Code completely before running this migration."
    exit 1
  fi
fi
green "✓ VS Code is closed."

# Find the old single-folder and new multi-root workspace storage IDs.
old_id=""
new_id=""

shopt -s nullglob
storage_dirs=("$VSCODE_STORAGE"/*/)
shopt -u nullglob
for d in "${storage_dirs[@]}"; do
  ws_file="$d/workspace.json"
  if [ -f "$ws_file" ]; then
    content="$(<"$ws_file")"
    if echo "$content" | grep -q "\"folder\".*${PROJECT_NAME}\"" &&
       echo "$content" | grep -qv "${WORKSPACE_FILE}"; then
      old_id="$(basename "$d")"
    fi
    if echo "$content" | grep -q "\"workspace\".*${WORKSPACE_FILE}"; then
      new_id="$(basename "$d")"
    fi
  fi
done

if [ -z "$old_id" ]; then
  red "✗ Old single-folder workspace not found for project '${PROJECT_NAME}'."
  echo "   Searched: ${VSCODE_STORAGE}"
  echo "   Expected workspace.json to identify a folder ending in /${PROJECT_NAME}."
  exit 1
fi
green "✓ Old workspace: $old_id"

if [ -z "$new_id" ]; then
  red "✗ New multi-root workspace '${WORKSPACE_FILE}' not found."
  echo "   Open ${WORKSPACE_FILE} in VS Code once, close VS Code, then retry."
  exit 1
fi
green "✓ New workspace: $new_id"

OLD="$VSCODE_STORAGE/$old_id"
NEW="$VSCODE_STORAGE/$new_id"
copied=0
copied_edits=0
migrated=0

# Migrate chat transcript files.
echo ""
yellow "── Chat transcripts ──"

if [ -d "$OLD/chatSessions" ]; then
  shopt -s nullglob
  old_files=("$OLD/chatSessions"/*.jsonl)
  shopt -u nullglob

  if [ "${#old_files[@]}" -gt 0 ]; then
    mkdir -p "$NEW/chatSessions"

    shopt -s nullglob
    existing_files=("$NEW/chatSessions"/*.jsonl)
    shopt -u nullglob
    existing_names=()
    for f in "${existing_files[@]}"; do
      existing_names+=("$(basename "$f" .jsonl)")
    done

    skipped=0
    for f in "${old_files[@]}"; do
      base="$(basename "$f" .jsonl)"
      if [[ " ${existing_names[*]} " == *" ${base} "* ]]; then
        ((skipped++)) || true
      else
        cp "$f" "$NEW/chatSessions/"
        ((copied++)) || true
      fi
    done

    if [ "$copied" -gt 0 ]; then
      green "✓ $copied new chat session files copied ($skipped already present)"
    else
      green "✓ All $skipped chat sessions already migrated — no new files to copy."
    fi
  else
    yellow "  No chat session files found."
  fi
else
  yellow "  No chatSessions directory in old workspace."
fi

# Migrate editing-session directories.
echo ""
yellow "── Editing sessions ──"

if [ -d "$OLD/chatEditingSessions" ]; then
  shopt -s nullglob
  old_dirs=("$OLD/chatEditingSessions"/*/)
  shopt -u nullglob

  if [ "${#old_dirs[@]}" -gt 0 ]; then
    mkdir -p "$NEW/chatEditingSessions"

    shopt -s nullglob
    existing_dirs=("$NEW/chatEditingSessions"/*/)
    shopt -u nullglob
    existing_edits=()
    for d in "${existing_dirs[@]}"; do
      existing_edits+=("$(basename "$d")")
    done

    skipped_edits=0
    for dir in "${old_dirs[@]}"; do
      base="$(basename "$dir")"
      if [[ " ${existing_edits[*]} " == *" ${base} "* ]]; then
        ((skipped_edits++)) || true
      else
        cp -r "$dir" "$NEW/chatEditingSessions/$base"
        ((copied_edits++)) || true
      fi
    done

    if [ "$copied_edits" -gt 0 ]; then
      green "✓ $copied_edits new editing session dirs copied ($skipped_edits already present)"
    else
      green "✓ All $skipped_edits editing sessions already migrated — no new dirs to copy."
    fi
  else
    yellow "  No editing session directories found."
  fi
else
  yellow "  No chatEditingSessions directory in old workspace."
fi

# Merge the chat index and upsert related workspace state.
echo ""
yellow "── State database keys ──"

OLD_DB="$OLD/state.vscdb"
NEW_DB="$NEW/state.vscdb"

if [ ! -f "$OLD_DB" ]; then
  yellow "  No state.vscdb found in old workspace."
elif [ ! -f "$NEW_DB" ]; then
  red "✗ No state.vscdb found in the new workspace."
  echo "   Open ${WORKSPACE_FILE} in VS Code once, close VS Code, then retry."
  exit 1
else
  old_index="$(sqlite3 "$OLD_DB" "SELECT value FROM ItemTable WHERE key = 'chat.ChatSessionStore.index';" 2>/dev/null || true)"
  new_index="$(sqlite3 "$NEW_DB" "SELECT value FROM ItemTable WHERE key = 'chat.ChatSessionStore.index';" 2>/dev/null || true)"

  if [ -n "$old_index" ] && [ -n "$new_index" ]; then
    # Old entries are added first so target-workspace entries win on duplicate
    # IDs, preserving any newer state already present in the target.
    merged="$(jq -n \
      --argjson old "$old_index" \
      --argjson new "$new_index" \
      '{version: ($new.version // $old.version), entries: ($old.entries + $new.entries)}' 2>/dev/null || true)"
    if [ -n "$merged" ]; then
      escaped="$(echo "$merged" | sed "s/'/''/g")"
      sqlite3 "$NEW_DB" "DELETE FROM ItemTable WHERE key = 'chat.ChatSessionStore.index';"
      sqlite3 "$NEW_DB" "INSERT INTO ItemTable (key, value) VALUES ('chat.ChatSessionStore.index', '$escaped');"
      green "✓ Session index merged (preserved target entries, added missing old entries)"
    fi
  elif [ -n "$old_index" ]; then
    escaped="$(echo "$old_index" | sed "s/'/''/g")"
    sqlite3 "$NEW_DB" "DELETE FROM ItemTable WHERE key = 'chat.ChatSessionStore.index';"
    sqlite3 "$NEW_DB" "INSERT INTO ItemTable (key, value) VALUES ('chat.ChatSessionStore.index', '$escaped');"
    green "✓ Session index copied from old workspace"
  fi

  KEYS=(
    "memento/chat-todo-list"
    "memento/workbench.editor.chatSession"
    "chat.contextUsage.hasBeenOpened"
    "chat.terminalSessions"
    "memento/webviewView.chatgpt.sidebarSecondaryView"
    "memento/interactive-session-view-copilot"
    "chat/autoconfirm"
    "chat/outputPartStateCache"
  )

  skipped_keys=0
  for key in "${KEYS[@]}"; do
    value="$(sqlite3 "$OLD_DB" "SELECT value FROM ItemTable WHERE key = '$key';" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      escaped="$(echo "$value" | sed "s/'/''/g")"
      sqlite3 "$NEW_DB" "DELETE FROM ItemTable WHERE key = '$key';"
      sqlite3 "$NEW_DB" "INSERT INTO ItemTable (key, value) VALUES ('$key', '$escaped');"
      ((migrated++)) || true
    else
      ((skipped_keys++)) || true
    fi
  done
  green "✓ $migrated other state keys migrated ($skipped_keys unavailable)"
fi

# Verify the target session index.
echo ""
yellow "── Verification ──"
index_value=""
if [ -f "$NEW_DB" ]; then
  index_value="$(sqlite3 "$NEW_DB" "SELECT value FROM ItemTable WHERE key = 'chat.ChatSessionStore.index';" 2>/dev/null || true)"
fi
if [ -n "$index_value" ]; then
  entry_count="$(echo "$index_value" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('entries',{})))" 2>/dev/null || echo "?")"
  green "✓ Session index: $entry_count entries"
else
  yellow "  No session index found in new workspace."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
green "✅ Migration complete."
echo ""
echo "  Project:          ${PROJECT_NAME}"
echo "  Old workspace:    ${old_id}"
echo "  New workspace:    ${new_id}"
echo "  Session files:    ${copied}"
echo "  Editing sessions: ${copied_edits}"
echo "  State keys:       ${migrated}"
echo ""
echo "  Next step: code ${WORKSPACE_FILE}"
echo "═══════════════════════════════════════════════════════════════════════════"
