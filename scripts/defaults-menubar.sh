#!/usr/bin/env bash
set -euo pipefail

# Apply menu bar / Control Center defaults.
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

echo "Applying menu bar defaults..."

# Show Bluetooth in menu bar
run defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true

# Restart ControlCenter to apply changes
if [ "$NO_RESTART" -eq 1 ]; then
	echo "Skipping ControlCenter restart (--no-restart)."
elif [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: killall ControlCenter"
else
	killall ControlCenter >/dev/null 2>&1 || true
fi

echo "Menu bar defaults applied."
