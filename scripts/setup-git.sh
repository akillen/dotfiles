#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-git.sh [--dry-run] [--yes] --name "Your Name" --email "you@example.com"

NAME=""
EMAIL=""
DRY_RUN=0
ASSUME_YES=0

while [[ ${1-} != "" ]]; do
  case "$1" in
    --name) shift; NAME="$1" ;;
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

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: $*"
  else
    eval "$@"
  fi
}

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
  echo "Git name and email must be provided. Skipping git configuration."
  exit 0
fi

echo "Configuring git: $NAME <$EMAIL>"
run git config --global user.name "$NAME"
run git config --global user.email "$EMAIL"
run git config --global init.defaultBranch main
run git config --global core.editor "code --wait"

echo "Configuring git aliases..."
run git config --global alias.co checkout
run git config --global alias.pom "'pull origin main'"
run git config --global alias.st status
run git config --global alias.br branch
run git config --global alias.lg "'log --oneline --graph --decorate --all'"
run git config --global alias.unstage "'reset HEAD --'"
run git config --global alias.undo "'reset --soft HEAD~1'"
run git config --global alias.aliases "'config --get-regexp alias'"

echo "Git configured."
