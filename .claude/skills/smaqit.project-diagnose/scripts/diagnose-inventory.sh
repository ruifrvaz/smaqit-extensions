#!/usr/bin/env bash
# diagnose-inventory.sh — stack-agnostic workspace inventory for smaqit.project-diagnose
#
# Run from workspace root:
#   bash ~/.claude/skills/smaqit.project-diagnose/scripts/diagnose-inventory.sh
#
# The agent sets StackProfile fields as environment variables before calling this script.
# All variables have auto-detection fallbacks so the script is always runnable stand-alone.
#
# Inputs (env vars — all optional):
#   DIAG_BACKEND_DIR             e.g. "backend"
#   DIAG_FRONTEND_DIR            e.g. "frontend"
#   DIAG_BACKEND_LANG            python|node|go|java|ruby|dotnet|unknown
#   DIAG_FRONTEND_LANG           typescript|javascript|unknown
#   DIAG_TEST_BACKEND_PATTERNS   comma-separated globs, e.g. "test_*.py,*_test.py"
#   DIAG_TEST_FRONTEND_PATTERNS  comma-separated globs, e.g. "*.test.ts,*.test.tsx"
#   DIAG_VENDOR_EXCLUDES         comma-separated dirs to prune, e.g. ".venv,node_modules"
#   DIAG_LOG_FILE                relative path to log module, e.g. "backend/logger.py"
#   DIAG_COMPOSE_FILE            relative path to compose file, e.g. "docker-compose.yml"
#   DIAG_BACKUP_SCRIPT           relative path to backup script, e.g. "scripts/backup.sh"
#
# Output: single JSON object to stdout
set -euo pipefail

# ---------------------------------------------------------------------------
# Auto-detect StackProfile fields if not provided by the agent
# ---------------------------------------------------------------------------

# backend_dir
DIAG_BACKEND_DIR="${DIAG_BACKEND_DIR:-}"
if [ -z "$DIAG_BACKEND_DIR" ]; then
  for d in backend src app server; do
    if [ -d "$d" ]; then DIAG_BACKEND_DIR="$d"; break; fi
  done
  DIAG_BACKEND_DIR="${DIAG_BACKEND_DIR:-.}"
fi

# frontend_dir
DIAG_FRONTEND_DIR="${DIAG_FRONTEND_DIR:-}"
if [ -z "$DIAG_FRONTEND_DIR" ]; then
  for d in frontend client web ui; do
    if [ -d "$d" ] && [ -f "$d/package.json" ]; then DIAG_FRONTEND_DIR="$d"; break; fi
  done
fi

# backend_lang
DIAG_BACKEND_LANG="${DIAG_BACKEND_LANG:-}"
if [ -z "$DIAG_BACKEND_LANG" ]; then
  if [ -f "$DIAG_BACKEND_DIR/pyproject.toml" ] || [ -f "$DIAG_BACKEND_DIR/requirements.txt" ] || [ -f "pyproject.toml" ]; then
    DIAG_BACKEND_LANG="python"
  elif [ -f "go.mod" ] || [ -f "$DIAG_BACKEND_DIR/go.mod" ]; then
    DIAG_BACKEND_LANG="go"
  elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
    DIAG_BACKEND_LANG="java"
  elif [ -f "Gemfile" ]; then
    DIAG_BACKEND_LANG="ruby"
  elif ls *.csproj 2>/dev/null | grep -q .; then
    DIAG_BACKEND_LANG="dotnet"
  elif [ -f "$DIAG_BACKEND_DIR/package.json" ] || [ -f "package.json" ]; then
    DIAG_BACKEND_LANG="node"
  else
    DIAG_BACKEND_LANG="unknown"
  fi
fi

# test patterns
DIAG_TEST_BACKEND_PATTERNS="${DIAG_TEST_BACKEND_PATTERNS:-}"
if [ -z "$DIAG_TEST_BACKEND_PATTERNS" ]; then
  case "$DIAG_BACKEND_LANG" in
    python)  DIAG_TEST_BACKEND_PATTERNS="test_*.py,*_test.py" ;;
    go)      DIAG_TEST_BACKEND_PATTERNS="*_test.go" ;;
    java)    DIAG_TEST_BACKEND_PATTERNS="*Test.java,*Spec.java,*IT.java" ;;
    ruby)    DIAG_TEST_BACKEND_PATTERNS="*_spec.rb,*_test.rb" ;;
    node)    DIAG_TEST_BACKEND_PATTERNS="*.test.js,*.spec.js,*.test.ts,*.spec.ts" ;;
    dotnet)  DIAG_TEST_BACKEND_PATTERNS="*Tests.cs,*Spec.cs" ;;
    *)       DIAG_TEST_BACKEND_PATTERNS="*test*,*spec*" ;;
  esac
fi
DIAG_TEST_FRONTEND_PATTERNS="${DIAG_TEST_FRONTEND_PATTERNS:-*.test.ts,*.test.tsx,*.spec.ts,*.spec.tsx,*.test.js,*.spec.js}"

# vendor excludes
DIAG_VENDOR_EXCLUDES="${DIAG_VENDOR_EXCLUDES:-}"
if [ -z "$DIAG_VENDOR_EXCLUDES" ]; then
  case "$DIAG_BACKEND_LANG" in
    python)  DIAG_VENDOR_EXCLUDES=".venv,__pycache__" ;;
    node)    DIAG_VENDOR_EXCLUDES="node_modules" ;;
    go)      DIAG_VENDOR_EXCLUDES="vendor" ;;
    java)    DIAG_VENDOR_EXCLUDES="target,build" ;;
    ruby)    DIAG_VENDOR_EXCLUDES="vendor/bundle" ;;
    dotnet)  DIAG_VENDOR_EXCLUDES="bin,obj" ;;
    *)       DIAG_VENDOR_EXCLUDES="vendor,node_modules" ;;
  esac
fi

# log file
DIAG_LOG_FILE="${DIAG_LOG_FILE:-}"
if [ -z "$DIAG_LOG_FILE" ]; then
  for candidate in \
      "$DIAG_BACKEND_DIR/logger.py" "$DIAG_BACKEND_DIR/logging.py" "$DIAG_BACKEND_DIR/log.py" \
      "$DIAG_BACKEND_DIR/logger.ts" "$DIAG_BACKEND_DIR/logger.js" \
      "$DIAG_BACKEND_DIR/logger.go" "$DIAG_BACKEND_DIR/internal/logger/logger.go" \
      "src/main/resources/logback.xml" "src/main/resources/log4j2.xml"; do
    if [ -f "$candidate" ]; then DIAG_LOG_FILE="$candidate"; break; fi
  done
  DIAG_LOG_FILE="${DIAG_LOG_FILE:-unknown}"
fi

# compose file
DIAG_COMPOSE_FILE="${DIAG_COMPOSE_FILE:-}"
if [ -z "$DIAG_COMPOSE_FILE" ]; then
  for candidate in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    if [ -f "$candidate" ]; then DIAG_COMPOSE_FILE="$candidate"; break; fi
  done
  DIAG_COMPOSE_FILE="${DIAG_COMPOSE_FILE:-none}"
fi

# backup script
DIAG_BACKUP_SCRIPT="${DIAG_BACKUP_SCRIPT:-}"
if [ -z "$DIAG_BACKUP_SCRIPT" ]; then
  for candidate in scripts/backup.sh backup.sh scripts/backup.py Makefile; do
    if [ -f "$candidate" ]; then DIAG_BACKUP_SCRIPT="$candidate"; break; fi
  done
  DIAG_BACKUP_SCRIPT="${DIAG_BACKUP_SCRIPT:-none}"
fi

# ---------------------------------------------------------------------------
# Helper: build find -not -path exclusion arguments from comma-separated list
# ---------------------------------------------------------------------------
build_exclude_args() {
  local excludes="$1" args=""
  IFS=',' read -ra parts <<< "$excludes"
  for ex in "${parts[@]}"; do
    ex="${ex#"${ex%%[![:space:]]*}"}"
    args="$args -not -path '*/${ex}/*'"
  done
  echo "$args"
}

BACKEND_EXCLUDES=$(build_exclude_args "$DIAG_VENDOR_EXCLUDES")
FRONTEND_EXCLUDES="-not -path '*/node_modules/*'"

# ---------------------------------------------------------------------------
# 1. Test file counts
# ---------------------------------------------------------------------------
count_test_files() {
  local dir="$1" patterns="$2" excludes="$3"
  [ ! -d "$dir" ] && echo 0 && return
  local total=0
  IFS=',' read -ra pats <<< "$patterns"
  for pat in "${pats[@]}"; do
    pat="${pat#"${pat%%[![:space:]]*}"}"
    n=$(eval "find \"$dir\" $excludes -name \"$pat\" 2>/dev/null" | wc -l | tr -d ' ')
    total=$((total + n))
  done
  echo "$total"
}

backend_tests=$(count_test_files "$DIAG_BACKEND_DIR" "$DIAG_TEST_BACKEND_PATTERNS" "$BACKEND_EXCLUDES")
frontend_tests=0
if [ -n "$DIAG_FRONTEND_DIR" ] && [ -d "$DIAG_FRONTEND_DIR" ]; then
  frontend_tests=$(count_test_files "$DIAG_FRONTEND_DIR" "$DIAG_TEST_FRONTEND_PATTERNS" "$FRONTEND_EXCLUDES")
fi

# ---------------------------------------------------------------------------
# 2. Test runner / config presence (language-adaptive)
# ---------------------------------------------------------------------------
has_backend_runner_config=false
has_backend_test_config=false
has_frontend_runner_config=false

case "$DIAG_BACKEND_LANG" in
  python)
    { [ -f "$DIAG_BACKEND_DIR/pytest.ini" ] || [ -f "pytest.ini" ] || \
      ([ -f "$DIAG_BACKEND_DIR/pyproject.toml" ] && grep -q 'tool.pytest' "$DIAG_BACKEND_DIR/pyproject.toml" 2>/dev/null); } \
      && has_backend_runner_config=true || true
    { [ -f "$DIAG_BACKEND_DIR/conftest.py" ] || [ -f "conftest.py" ]; } \
      && has_backend_test_config=true || true
    ;;
  go)
    grep -rq 'testify\|testing.T' "$DIAG_BACKEND_DIR" 2>/dev/null \
      && has_backend_runner_config=true || true
    has_backend_test_config=true
    ;;
  java)
    { [ -f "pom.xml" ] && grep -q 'maven-surefire\|junit\|testng' pom.xml 2>/dev/null; } \
      && has_backend_runner_config=true || true
    ;;
  node|dotnet|ruby)
    { ls "$DIAG_BACKEND_DIR"/jest.config.* 2>/dev/null | grep -q . || \
      ls "$DIAG_BACKEND_DIR"/vitest.config.* 2>/dev/null | grep -q .; } \
      && has_backend_runner_config=true || true
    ;;
esac

if [ -n "$DIAG_FRONTEND_DIR" ] && [ -d "$DIAG_FRONTEND_DIR" ]; then
  { ls "$DIAG_FRONTEND_DIR"/vitest.config.* 2>/dev/null | grep -q . || \
    ls "$DIAG_FRONTEND_DIR"/jest.config.* 2>/dev/null | grep -q . || \
    ls vitest.config.* 2>/dev/null | grep -q .; } \
    && has_frontend_runner_config=true || true
fi

# ---------------------------------------------------------------------------
# 3. CI workflows: list non-smaqit workflow files
# ---------------------------------------------------------------------------
ci_files=()
ci_dir_detected="none"

if [ -d ".github/workflows" ]; then
  ci_dir_detected=".github/workflows"
  for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    echo "$fname" | grep -qi 'smaqit' && continue || true
    head -10 "$f" 2>/dev/null | grep -qi 'smaqit' && continue || true
    ci_files+=("$fname")
  done
elif [ -f ".gitlab-ci.yml" ]; then
  ci_dir_detected=".gitlab-ci.yml"
  ci_files+=(".gitlab-ci.yml")
elif [ -f "Jenkinsfile" ]; then
  ci_dir_detected="Jenkinsfile"
  ci_files+=("Jenkinsfile")
fi

# ---------------------------------------------------------------------------
# 4. Log handler type (language-adaptive)
# ---------------------------------------------------------------------------
log_handler="unknown"
if [ -f "$DIAG_LOG_FILE" ]; then
  case "$DIAG_BACKEND_LANG" in
    python)
      if grep -q 'RotatingFileHandler\|TimedRotatingFileHandler' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="rotating"
      elif grep -q 'FileHandler' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="file"
      elif grep -q 'StreamHandler\|console' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="stream"
      fi ;;
    node)
      if grep -qi 'DailyRotateFile\|rotating\|winston-daily' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="rotating"
      elif grep -qi 'transports.File\|createWriteStream' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="file"
      else
        log_handler="stream"
      fi ;;
    go)
      if grep -qi 'lumberjack\|rotating\|rollingfile' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="rotating"
      elif grep -qi 'os.Create\|os.OpenFile' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="file"
      else
        log_handler="stream"
      fi ;;
    java)
      if grep -qi 'RollingFileAppender\|SizeAndTimeBasedRollingPolicy' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="rotating"
      elif grep -qi 'FileAppender' "$DIAG_LOG_FILE" 2>/dev/null; then
        log_handler="file"
      fi ;;
    *)
      grep -qi 'rotat' "$DIAG_LOG_FILE" 2>/dev/null && log_handler="rotating" || \
        grep -qi 'file' "$DIAG_LOG_FILE" 2>/dev/null && log_handler="file" || true
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# 5. Log volume mount
# ---------------------------------------------------------------------------
log_volume=false
if [ "$DIAG_COMPOSE_FILE" != "none" ] && [ -f "$DIAG_COMPOSE_FILE" ]; then
  grep -E '\./logs|/var/log/app' "$DIAG_COMPOSE_FILE" 2>/dev/null | grep -q . && log_volume=true || true
fi

# ---------------------------------------------------------------------------
# 6. Container services: logging config and healthchecks (generic, via python3)
# ---------------------------------------------------------------------------
all_services=""
logging_svcs=""
hc_svcs=""

if [ "$DIAG_COMPOSE_FILE" != "none" ] && [ -f "$DIAG_COMPOSE_FILE" ]; then
  _svc_data=$(python3 - "$DIAG_COMPOSE_FILE" << 'PYEOF'
import re, sys, json
content = open(sys.argv[1]).read()
lines = content.split("\n")
cur = None
has_logging, has_hc, services = set(), set(), set()
for line in lines:
    m = re.match(r"^  (\w[\w-]*):", line)
    if m:
        cur = m.group(1)
        services.add(cur)
    if cur:
        if re.match(r"\s{4,}logging:", line): has_logging.add(cur)
        if re.match(r"\s{4,}healthcheck:", line): has_hc.add(cur)
print(json.dumps({"services": sorted(services), "logging": sorted(has_logging), "healthcheck": sorted(has_hc)}))
PYEOF
  )
  all_services=$(echo "$_svc_data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(d['services']))" 2>/dev/null || true)
  logging_svcs=$(echo "$_svc_data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(d['logging']))" 2>/dev/null || true)
  hc_svcs=$(echo "$_svc_data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(d['healthcheck']))" 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# 7. Backup script — generic coverage checks
# ---------------------------------------------------------------------------
backup_hardcoded_path="not found"
backup_has_db=false
backup_has_config=false
backup_has_volumes=false

if [ "$DIAG_BACKUP_SCRIPT" != "none" ] && [ -f "$DIAG_BACKUP_SCRIPT" ]; then
  # Hardcoded deployment path variable
  _raw=$(grep -E '^(APP_DIR|BACKUP_DIR|BASE_DIR|DEPLOY_DIR|PROJECT_DIR)=' "$DIAG_BACKUP_SCRIPT" 2>/dev/null | head -1 || true)
  if [ -n "$_raw" ]; then
    backup_hardcoded_path=$(echo "$_raw" | sed 's/^[^=]*=//' | tr -d '"' | tr -d "'")
  fi
  # Database backup utility
  grep -qiE 'pg_dump|pg_dumpall|mysqldump|mongodump|sqlite3.*backup|db.backup|database.backup' \
    "$DIAG_BACKUP_SCRIPT" 2>/dev/null && backup_has_db=true || true
  # Config/secrets backup
  grep -qiE '\.env|config\.yml|config\.json|secrets' \
    "$DIAG_BACKUP_SCRIPT" 2>/dev/null && backup_has_config=true || true
  # Volume/data directory backup
  grep -qiE 'volumes?/|data/|tar |rsync|cp -r' \
    "$DIAG_BACKUP_SCRIPT" 2>/dev/null && backup_has_volumes=true || true
fi

# ---------------------------------------------------------------------------
# 8. Systemd unit
# ---------------------------------------------------------------------------
systemd_unit=false
find . -maxdepth 4 -name '*.service' 2>/dev/null | grep -q . && systemd_unit=true || true

# ---------------------------------------------------------------------------
# 9. Secrets tool
# ---------------------------------------------------------------------------
secret_tool="none"
if [ -f ".sops.yaml" ] || [ -f ".sops.yml" ]; then
  secret_tool="sops"
elif grep -qr 'ansible-vault' deploy/ scripts/ 2>/dev/null; then
  secret_tool="ansible-vault"
elif [ -f ".vault-token" ] || grep -qr '"vault"' deploy/ 2>/dev/null; then
  secret_tool="vault"
fi

# ---------------------------------------------------------------------------
# 10. .env.example keys (field names only, no values)
# ---------------------------------------------------------------------------
env_keys=()
for envfile in .env.example .env.sample .env.template; do
  if [ -f "$envfile" ]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue || true
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue || true
      key=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
      [ -n "$key" ] && env_keys+=("$key") || true
    done < "$envfile"
    break
  fi
done

# ---------------------------------------------------------------------------
# Serialize and output JSON
# ---------------------------------------------------------------------------
ci_count="${#ci_files[@]}"
ci_json=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${ci_files[@]+"${ci_files[@]}"}" 2>/dev/null || echo "[]")
keys_json=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${env_keys[@]+"${env_keys[@]}"}" 2>/dev/null || echo "[]")

# Convert bash true/false to Python True/False
_py() { [ "$1" = "true" ] && echo "True" || echo "False"; }
_py_backend_runner=$(_py "$has_backend_runner_config")
_py_backend_test=$(_py "$has_backend_test_config")
_py_frontend_runner=$(_py "$has_frontend_runner_config")
_py_log_volume=$(_py "$log_volume")
_py_backup_db=$(_py "$backup_has_db")
_py_backup_config=$(_py "$backup_has_config")
_py_backup_volumes=$(_py "$backup_has_volumes")
_py_systemd=$(_py "$systemd_unit")

python3 - << PYEOF
import json
print(json.dumps({
    "stack_profile": {
        "backend_dir": "${DIAG_BACKEND_DIR}",
        "frontend_dir": "${DIAG_FRONTEND_DIR:-}",
        "backend_lang": "${DIAG_BACKEND_LANG}",
        "log_file": "${DIAG_LOG_FILE}",
        "compose_file": "${DIAG_COMPOSE_FILE}",
        "backup_script": "${DIAG_BACKUP_SCRIPT}"
    },
    "test_files": {"backend": ${backend_tests}, "frontend": ${frontend_tests}},
    "test_configs": {
        "backend_runner_config": ${_py_backend_runner},
        "backend_test_fixtures": ${_py_backend_test},
        "frontend_runner_config": ${_py_frontend_runner}
    },
    "ci_workflows": {"count": ${ci_count}, "ci_dir": "${ci_dir_detected}", "files": ${ci_json}},
    "logging": {"handler_type": "${log_handler}", "volume_mount": ${_py_log_volume}},
    "container": {
        "compose_file": "${DIAG_COMPOSE_FILE}",
        "all_services": "${all_services:-}",
        "services_with_logging": "${logging_svcs:-}",
        "services_with_healthcheck": "${hc_svcs:-}"
    },
    "backup": {
        "script": "${DIAG_BACKUP_SCRIPT}",
        "hardcoded_path": "${backup_hardcoded_path}",
        "covers_database": ${_py_backup_db},
        "covers_config": ${_py_backup_config},
        "covers_volumes": ${_py_backup_volumes}
    },
    "provisioning": {"systemd_unit": ${_py_systemd}, "secret_tool": "${secret_tool}"},
    "env_example_keys": ${keys_json}
}, indent=2))
PYEOF
