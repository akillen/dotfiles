#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-ssh.sh [--dry-run] [--yes] --email you@example.com

EMAIL=""
DRY_RUN=0
ASSUME_YES=0
while [[ ${1-} != "" ]]; do
  case "$1" in
    --email) shift; EMAIL="$1" ;;
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help)
      sed -n '1,200p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

KEY_FILE="$HOME/.ssh/id_ed25519"

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: $*"
  else
    eval "$@"
  fi
}

if [ -f "$KEY_FILE" ]; then
  echo "SSH key already exists at $KEY_FILE. Skipping generation."
  exit 0
fi

if [ -z "$EMAIL" ]; then
  echo "Email required to generate SSH key. Skipping."
  exit 0
fi

echo "Generating SSH key for $EMAIL"
run ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_FILE" -N ""

# Start ssh-agent and add key to keychain
if [ "$DRY_RUN" -eq 0 ]; then
  eval "$(ssh-agent -s)"
  ssh-add --apple-use-keychain "$KEY_FILE"
fi

# Copy public key to clipboard for convenience
if [ -f "$KEY_FILE.pub" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: pbcopy < '$KEY_FILE.pub'"
  else
    pbcopy < "$KEY_FILE.pub"
    echo "Public key copied to clipboard."
  fi
fi

echo "SSH setup complete."
