#!/usr/bin/env bash
set -euo pipefail

# Apply Dock defaults safely (supports --dry-run, --yes, --no-restart)

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

echo "Applying Dock defaults..."

# Move the dock to the right side of the screen
run defaults write com.apple.dock orientation -string right

# Set the icon size
run defaults write com.apple.dock tilesize -int 36

# Enable auto-hide for the dock
run defaults write com.apple.dock autohide -bool true

# Restart Dock to apply (unless disabled)
if [ "$NO_RESTART" -eq 1 ]; then
	echo "Skipping Dock restart (--no-restart)."
elif [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: killall Dock"
else
	killall Dock >/dev/null 2>&1 || true
fi
echo "Dock defaults applied."
