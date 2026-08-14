#!/usr/bin/env bash
# Extract and validate the task-owned issue-triage context before model inspection.
set -euo pipefail

usage() {
  echo "task context: usage: task-context.sh [--allow-legacy] <task-file>" >&2
  exit 2
}

allow_legacy=false
if [ "${1:-}" = "--allow-legacy" ]; then
  allow_legacy=true
  shift
fi
[ "$#" -eq 1 ] || usage

task_file="$1"
if [ ! -f "$task_file" ]; then
  echo "task context: task file not found" >&2
  exit 1
fi

normalize() {
  awk '{$1=$1; print}' <<<"$1"
}

is_placeholder() {
  case "$1" in
    ""|TBD|"["*"]") return 0 ;;
    *) return 1 ;;
  esac
}

if structured="$(awk '
  function fail(message) { print "task context: " message > "/dev/stderr"; invalid = 1 }
  function capture(field, value, position) {
    if (seen[field]++) { fail("duplicate field: " field); return }
    if (++field_count != position) { fail("fields must use canonical order"); return }
    if (value == "") { fail("blank field: " field); return }
    values[field] = value
  }
  {
    line = $0
    sub(/\r$/, "", line)
    if (line ~ /^##[[:space:]]+/) {
      if (line ~ /^##[[:space:]]+Issue Triage Context[[:space:]]*$/) {
        if (++heading_count > 1) { fail("duplicate Issue Triage Context section") }
        in_context = 1
      } else {
        in_context = 0
      }
      next
    }
    if (!in_context || line ~ /^[[:space:]]*$/) { next }
    if (line ~ /^\*\*Mode:\*\*[[:space:]]*/) {
      value = line; sub(/^\*\*Mode:\*\*[[:space:]]*/, "", value); capture("Mode", value, 1)
    } else if (line ~ /^\*\*Technologies:\*\*[[:space:]]*/) {
      value = line; sub(/^\*\*Technologies:\*\*[[:space:]]*/, "", value); capture("Technologies", value, 2)
    } else if (line ~ /^\*\*Platforms\/Environments:\*\*[[:space:]]*/) {
      value = line; sub(/^\*\*Platforms\/Environments:\*\*[[:space:]]*/, "", value); capture("Platforms/Environments", value, 3)
    } else if (line ~ /^\*\*Features\/Integrations:\*\*[[:space:]]*/) {
      value = line; sub(/^\*\*Features\/Integrations:\*\*[[:space:]]*/, "", value); capture("Features/Integrations", value, 4)
    } else if (line ~ /^\*\*Versions\/Constraints:\*\*[[:space:]]*/) {
      value = line; sub(/^\*\*Versions\/Constraints:\*\*[[:space:]]*/, "", value); capture("Versions/Constraints", value, 5)
    } else {
      fail("unexpected content in Issue Triage Context")
    }
  }
  END {
    if (heading_count == 0) { exit 3 }
    required[1] = "Mode"
    required[2] = "Technologies"
    required[3] = "Platforms/Environments"
    required[4] = "Features/Integrations"
    required[5] = "Versions/Constraints"
    for (i = 1; i <= 5; i++) {
      field = required[i]
      if (!(field in seen)) { fail("missing field: " field) }
    }
    if (invalid) { exit 2 }
    for (i = 1; i <= 5; i++) {
      field = required[i]
      print field "\t" values[field]
    }
  }
' "$task_file")"; then
  source_kind="structured"
else
  parse_status=$?
  if [ "$parse_status" -ne 3 ] || [ "$allow_legacy" != true ]; then
    exit "$parse_status"
  fi
  echo "task context: legacy task format; migrate to Issue Triage Context" >&2
  source_kind="legacy"
  structured="$(awk '
    function append(name, line) { content[name] = content[name] == "" ? line : content[name] ORS line }
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^##[[:space:]]+/) {
        current = ""
        if (line ~ /^##[[:space:]]+Description[[:space:]]*$/) current = "Description"
        else if (line ~ /^##[[:space:]]+Acceptance Criteria[[:space:]]*$/) current = "Acceptance Criteria"
        else if (line ~ /^##[[:space:]]+Notes[[:space:]]*$/) current = "Notes"
        seen[current] = current != ""
        next
      }
      if (current != "") append(current, line)
    }
    END {
      required[1] = "Description"; required[2] = "Acceptance Criteria"; required[3] = "Notes"
      for (i = 1; i <= 3; i++) if (!seen[required[i]]) { print "task context: legacy task missing section: " required[i] > "/dev/stderr"; exit 2 }
      print "## Description\n" content["Description"] "\n\n## Acceptance Criteria\n" content["Acceptance Criteria"] "\n\n## Notes\n" content["Notes"]
    }
  ' "$task_file")"
fi

if [ "$source_kind" = "legacy" ]; then
  legacy_signal="$structured"
  legacy_mode="Auto"
  case "$legacy_signal" in *"triage: skip"*) legacy_mode="Skip" ;; esac
  jq -cn --arg source "$source_kind" --arg mode "$legacy_mode" --arg signal "$legacy_signal" \
    '{source: $source, mode: $mode, legacy_signal: $signal}'
  exit 0
fi

declare -A values=()
while IFS=$'\t' read -r field value; do
  values["$field"]="$value"
done <<<"$structured"

for field in Mode Technologies Platforms/Environments Features/Integrations Versions/Constraints; do
  values["$field"]="$(normalize "${values[$field]}")"
  if is_placeholder "${values[$field]}"; then
    echo "task context: invalid placeholder in $field" >&2
    exit 2
  fi
done

case "${values[Mode]}" in
  Auto|Skip) ;;
  *) echo "task context: Mode must be Auto or Skip" >&2; exit 2 ;;
esac

if [ "${values[Mode]}" = "Auto" ] && [ "${values[Technologies]}" != "None" ] && [ "${values[Features/Integrations]}" = "None" ]; then
  echo "task context: Auto context with Technologies requires Features/Integrations" >&2
  exit 2
fi

canonical="Mode=${values[Mode]}\nTechnologies=${values[Technologies]}\nPlatforms/Environments=${values[Platforms/Environments]}\nFeatures/Integrations=${values[Features/Integrations]}\nVersions/Constraints=${values[Versions/Constraints]}\n"
if command -v sha256sum >/dev/null 2>&1; then
  digest="$(printf '%b' "$canonical" | sha256sum | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  digest="$(printf '%b' "$canonical" | shasum -a 256 | awk '{print $1}')"
else
  echo "task context: sha256sum or shasum is required" >&2
  exit 1
fi

jq -cn \
  --arg source "$source_kind" \
  --arg mode "${values[Mode]}" \
  --arg technologies "${values[Technologies]}" \
  --arg platforms "${values[Platforms/Environments]}" \
  --arg features "${values[Features/Integrations]}" \
  --arg versions "${values[Versions/Constraints]}" \
  --arg fingerprint "sha256:$digest" \
  '{source: $source, mode: $mode, technologies: $technologies, platforms: $platforms, features: $features, versions: $versions, fingerprint: $fingerprint}'
