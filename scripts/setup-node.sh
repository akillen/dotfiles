#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-node.sh [--dry-run] [--yes] [--node-version node] [--npm-version latest]

DRY_RUN=0
ASSUME_YES=0
NODE_VERSION="node"
NPM_VERSION="latest"

while [[ ${1-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --node-version)
      shift
      NODE_VERSION="${1-}"
      ;;
    --npm-version)
      shift
      NPM_VERSION="${1-}"
      ;;
    -h|--help)
      sed -n '1,220p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
  shift
done

echo "Setting up Node.js with nvm..."

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required before running setup-node.sh"
  exit 1
fi

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_PREFIX="$(brew --prefix nvm 2>/dev/null || true)"
NVM_SH="${NVM_PREFIX}/nvm.sh"
NVM_COMPLETION="${NVM_PREFIX}/etc/bash_completion.d/nvm"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: mkdir -p '$NVM_DIR'"
  echo "DRY RUN: source '$NVM_SH'"
  echo "DRY RUN: nvm install '$NODE_VERSION'"
  echo "DRY RUN: nvm alias default '$NODE_VERSION'"
  echo "DRY RUN: nvm use default"
  echo "DRY RUN: npm install -g 'npm@$NPM_VERSION'"
  return 0 2>/dev/null || exit 0
fi

mkdir -p "$NVM_DIR"

if [ ! -s "$NVM_SH" ]; then
  echo "nvm.sh not found at $NVM_SH"
  echo "Ensure Brewfile has 'brew \"nvm\"' and brew bundle completed successfully."
  exit 1
fi

# shellcheck disable=SC1090
. "$NVM_SH"
if [ -s "$NVM_COMPLETION" ]; then
  # shellcheck disable=SC1090
  . "$NVM_COMPLETION"
fi

nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use default >/dev/null

if command -v npm >/dev/null 2>&1; then
  npm install -g "npm@$NPM_VERSION"
else
  echo "npm was not found after nvm setup."
  exit 1
fi

echo "Node version: $(node -v)"
echo "npm version: $(npm -v)"
if command -v npx >/dev/null 2>&1; then
  echo "npx version: $(npx --version)"
else
  echo "npx command not found (npm 10+ still supports 'npm exec')."
fi
