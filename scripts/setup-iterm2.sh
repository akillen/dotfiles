#!/usr/bin/env bash
set -euo pipefail

# Configure iTerm2 to load preferences from this directory.
# Supports: --dry-run, --yes

DRY_RUN=0
ASSUME_YES=0

while [[ ${1-} != "" ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--yes) ASSUME_YES=1 ;;
		-h|--help) sed -n '1,200p' "$0"; exit 0 ;;
		*) echo "Unknown arg: $1"; exit 1 ;;
	esac
	shift
done

run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		echo "DRY RUN: $*"
	else
		"$@"
	fi
}

ITERM_PREFS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../iterm2" >/dev/null 2>&1 && pwd)"

echo "Configuring iTerm2 settings..."

if [ ! -d "/Applications/iTerm.app" ]; then
	echo "iTerm.app not found; skipping settings configuration."
	exit 0
fi

# Specify the custom folder to load preferences from
run defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$ITERM_PREFS_DIR"

# Tell iTerm2 to use the custom folder
run defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

echo "iTerm2 configured to use preferences from: $ITERM_PREFS_DIR"
