#!/usr/bin/env bash
set -euo pipefail

# Apply Finder defaults safely (idempotent)
# Supports: --dry-run, --yes, --no-restart

DRY_RUN=0
ASSUME_YES=0
NO_RESTART=0

while [[ ${1-} != "" ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--yes) ASSUME_YES=1 ;;
		--no-restart) NO_RESTART=1 ;;
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

echo "Applying Finder defaults..."

# Show hidden files
run defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
run defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Restart Finder to apply (unless disabled)
if [ "$NO_RESTART" -eq 1 ]; then
	echo "Skipping Finder restart (--no-restart)."
elif [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: killall Finder"
else
	killall Finder >/dev/null 2>&1 || true
fi
echo "Finder defaults applied."
