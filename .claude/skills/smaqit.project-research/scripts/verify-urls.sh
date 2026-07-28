#!/usr/bin/env bash
# verify-urls.sh — Liveness verifier for smaqit.research
#
# Usage: verify-urls.sh <input-file>
#
# Input:  newline-delimited file; each line is tab-separated: TOOL\tSECTION\tURL
# Output: tab-separated lines to stdout: TOOL\tSECTION\tFINAL_URL\tSTATUS_CODE
#         Only lines with HTTP 200 are printed.
# Progress (stderr): [CHECK], [OK], [ERROR] prefixed lines.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "[ERROR] Usage: $0 <input-file>" >&2
    exit 1
fi

INPUT_FILE="$1"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "[ERROR] Input file not found: $INPUT_FILE" >&2
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "[ERROR] curl is not available — cannot run liveness verification" >&2
    exit 1
fi

while IFS=$'\t' read -r tool section url; do
    # Skip blank lines or lines missing a URL field
    [[ -z "${url:-}" ]] && continue

    echo "[CHECK] $tool — $section — $url" >&2

    result=$(curl --head --silent --location --max-time 5 \
        -w "%{http_code}\n%{url_effective}" \
        -o /dev/null \
        "$url" 2>/dev/null) || true

    if [[ -z "${result:-}" ]]; then
        echo "[ERROR] curl returned no output for: $url" >&2
        continue
    fi

    status=$(printf '%s' "$result" | head -1)
    final_url=$(printf '%s' "$result" | tail -1)

    if [[ "$status" == "200" ]]; then
        echo "[OK] $status — $url" >&2
        printf '%s\t%s\t%s\t%s\n' "$tool" "$section" "$final_url" "$status"
    else
        echo "[ERROR] $status — $url" >&2
    fi
done < "$INPUT_FILE"
