#!/usr/bin/env bash
set -euo pipefail

# Apply trackpad defaults safely.
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

echo "Applying Trackpad defaults..."

# Enable tap-to-click for the built-in trackpad and external Apple trackpads.
run defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
run defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
run defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Refresh preferences daemons so the setting applies without a full reboot when possible.
if [ "$NO_RESTART" -eq 1 ]; then
	echo "Skipping preferences daemon restart (--no-restart)."
elif [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: killall cfprefsd"
	echo "DRY RUN: killall SystemUIServer"
else
	killall cfprefsd >/dev/null 2>&1 || true
	killall SystemUIServer >/dev/null 2>&1 || true
fi

echo "Trackpad defaults applied. You may need to log out and back in for tap-to-click to take effect immediately."