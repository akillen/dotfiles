#!/usr/bin/env bash
set -euo pipefail

# Fails if tracked .zshrc contains machine-specific absolute asdf init paths.
# Usage: check-zshrc-portability.sh /path/to/.zshrc

TARGET_FILE="${1-}"

if [ -z "$TARGET_FILE" ]; then
  echo "Usage: $(basename "$0") /path/to/.zshrc"
  exit 1
fi

if [ ! -f "$TARGET_FILE" ]; then
  echo "Error: file not found: $TARGET_FILE"
  exit 1
fi

PATTERN="^[[:space:]]*(\\.|source)[[:space:]]+[\"']?/(usr/local|opt/homebrew)/opt/asdf/libexec/asdf\\.sh[\"']?[[:space:]]*$"
MATCHES="$(grep -nE "$PATTERN" "$TARGET_FILE" || true)"

if [ -n "$MATCHES" ]; then
  echo "Error: machine-specific asdf init path(s) detected in $TARGET_FILE"
  echo "Remove lines similar to:"
  echo "  . '/usr/local/opt/asdf/libexec/asdf.sh'"
  echo "  . '/opt/homebrew/opt/asdf/libexec/asdf.sh'"
  echo "Found:"
  echo "$MATCHES"
  exit 1
fi

echo "Preflight OK: $TARGET_FILE has no machine-specific asdf init paths."
