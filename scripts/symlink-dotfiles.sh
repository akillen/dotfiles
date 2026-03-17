#!/usr/bin/env bash
set -euo pipefail

# Safe symlink deployer for dotfiles
# Usage: scripts/symlink-dotfiles.sh [--dry-run] [--yes]
# - --dry-run: show actions without making changes
# - --yes: don't prompt for confirmation when backing up

DRY_RUN=0
ASSUME_YES=0

while [[ ${1-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help)
      sed -n '1,120p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

# Determine repo root (parent of this scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
BACKUP_ROOT="$HOME/dotfiles_backup"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

EXCLUDES=(.git .gitignore .DS_Store Brewfile setup.sh scripts SETUP.md)

echo "Dotfiles dir: $DOTFILES_DIR"
echo "Backup dir: $BACKUP_DIR"

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: $*"
  else
    eval "$@"
  fi
}

mkdir -p "$BACKUP_ROOT"

# Find candidate dotfiles in repo root (names that start with a dot)
shopt -s dotglob 2>/dev/null || true
for src in "$DOTFILES_DIR"/.[!.]* "$DOTFILES_DIR"/..?*; do
  # Skip if doesn't exist (pattern may expand literally)
  [ -e "$src" ] || continue

  name="$(basename "$src")"

  # Skip excluded names
  skip=0
  for ex in "${EXCLUDES[@]}"; do
    if [ "$name" = "$ex" ]; then skip=1; break; fi
  done
  [ "$skip" -eq 1 ] && continue

  dest="$HOME/$name"

  # If dest is a symlink pointing to src, skip
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "OK: $dest -> already points to $src"
    continue
  fi

  # If dest exists and is not the desired symlink, back it up
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "Found existing $dest"
    if [ "$ASSUME_YES" -eq 0 ]; then
      read -r -p "Backup and replace $dest? [y/N]: " yn
      case "$yn" in
        [Yy]*) ;;
        *) echo "Skipping $dest"; continue ;;
      esac
    fi

    echo "Backing up $dest -> $BACKUP_DIR/"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY RUN: mkdir -p '$BACKUP_DIR' && mv '$dest' '$BACKUP_DIR/'"
    else
      mkdir -p "$BACKUP_DIR"
      mv "$dest" "$BACKUP_DIR/"
    fi
  fi

  # Ensure parent dir exists for dest (usually $HOME)
  parent_dir="$(dirname "$dest")"
  run mkdir -p "$parent_dir"

  # Create symlink
  echo "Linking $src -> $dest"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: ln -sfn '$src' '$dest'"
  else
    ln -sfn "$src" "$dest"
  fi
done

echo "Done. Backups (if any) are in: $BACKUP_DIR"

exit 0
