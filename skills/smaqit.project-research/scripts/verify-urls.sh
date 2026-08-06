#!/usr/bin/env bash
# verify-urls.sh — Liveness verifier for smaqit.research
#
# Usage: verify-urls.sh <input-file>
#
# Input:  newline-delimited file; each line is tab-separated: TOOL\tSECTION\tURL\tLAYER
#         LAYER must be exactly "project" or "task".
# Output: tab-separated lines to stdout: TOOL\tSECTION\tFINAL_URL\tSTATUS_CODE\tLAYER
#         Only lines with a final 2xx status are printed. HEAD is tried first;
#         a single bounded GET (body discarded) is attempted when HEAD does not
#         return 2xx, before giving up.
# Progress (stderr): [CHECK], [INFO], [OK], [ERROR] prefixed lines.

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

is_2xx() {
    [[ "$1" =~ ^2[0-9][0-9]$ ]]
}

probe() {
    # $1: url; remaining args are extra curl flags (e.g. --head)
    local url="$1"
    shift
    curl "$@" --silent --location --max-time 5 \
        -w '%{http_code}\n%{url_effective}' \
        -o /dev/null \
        "$url" 2>/dev/null || true
}

while IFS=$'\t' read -r tool section url layer; do
    # Skip fully blank lines
    [[ -z "${tool:-}${section:-}${url:-}${layer:-}" ]] && continue

    if [[ -z "${url:-}" || ( "$layer" != "project" && "$layer" != "task" ) ]]; then
        echo "[ERROR] Malformed record (expected 4 fields TOOL/SECTION/URL/LAYER with LAYER=project|task): $tool | $section | $url | $layer" >&2
        continue
    fi

    echo "[CHECK] $tool — $section — $url ($layer)" >&2

    result="$(probe "$url" --head)"
    status="$(printf '%s' "$result" | head -1)"
    final_url="$(printf '%s' "$result" | tail -1)"

    if ! is_2xx "$status"; then
        echo "[INFO] HEAD returned ${status:-no response} — retrying with GET: $url" >&2
        result="$(probe "$url")"
        status="$(printf '%s' "$result" | head -1)"
        final_url="$(printf '%s' "$result" | tail -1)"
    fi

    if is_2xx "$status"; then
        echo "[OK] $status — $url" >&2
        printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$section" "$final_url" "$status" "$layer"
    else
        echo "[ERROR] ${status:-no response} — $url" >&2
    fi
done < "$INPUT_FILE"
