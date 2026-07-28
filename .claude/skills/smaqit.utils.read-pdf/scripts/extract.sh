#!/usr/bin/env bash
set -euo pipefail

# extract.sh — Extract text from a PDF file using pdftotext.
#
# Usage: extract.sh <pdf-path>
#
# Writes a sidecar <pdf-basename>.extracted.txt next to the source PDF.
# Prints the sidecar path to stdout on success.
# Requires: poppler-utils (pdftotext)

PDF_PATH="${1:-}"

# --- Validate input ---

if [[ -z "$PDF_PATH" ]]; then
    echo "[ERROR] Usage: extract.sh <pdf-path>" >&2
    exit 1
fi

# --- Check dependency ---

if ! command -v pdftotext &>/dev/null; then
    echo "[ERROR] pdftotext is not installed." >&2
    echo "sudo apt install poppler-utils" >&2
    exit 1
fi

echo "[CHECK] pdftotext found: $(command -v pdftotext)"

# --- Check source file ---

if [[ ! -f "$PDF_PATH" ]]; then
    echo "[ERROR] PDF file not found: $PDF_PATH" >&2
    exit 1
fi

echo "[CHECK] Source PDF: $PDF_PATH"

# --- Derive sidecar path ---

PDF_DIR="$(dirname "$PDF_PATH")"
PDF_BASENAME="$(basename "$PDF_PATH" .pdf)"
SIDECAR_PATH="${PDF_DIR}/${PDF_BASENAME}.extracted.txt"

# --- Extract ---

echo "[CHECK] Extracting text to: $SIDECAR_PATH"

pdftotext -layout "$PDF_PATH" "$SIDECAR_PATH"

# --- Validate output ---

if [[ ! -s "$SIDECAR_PATH" ]]; then
    echo "[ERROR] Extracted text is empty — PDF may be image-only or protected" >&2
    exit 1
fi

echo "[OK] Extraction complete: $SIDECAR_PATH"

# Print sidecar path to stdout for the caller to consume
echo "$SIDECAR_PATH"
