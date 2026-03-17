#!/usr/bin/env bash
set -euo pipefail

# Apply Dock defaults safely.
# Supports: --dry-run, --yes, --no-restart, --running-only

DRY_RUN=0
ASSUME_YES=0
NO_RESTART=0
RUNNING_ONLY=0

while [[ ${1-} != "" ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--yes) ASSUME_YES=1 ;;
		--no-restart) NO_RESTART=1 ;;
		--running-only) RUNNING_ONLY=1 ;;
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

run_nonfatal() {
	if [ "$DRY_RUN" -eq 1 ]; then
		echo "DRY RUN: $*"
	else
		"$@" >/dev/null 2>&1 || true
	fi
}

remove_default_dock_items() {
	# Explicit list requested for removal/hiding from Dock.
	local default_apps=(
		"Finder"
		"Launchpad"
		"Safari"
		"Messages"
		"Mail"
		"Maps"
		"Photos"
		"FaceTime"
		"Phone"
		"Calendar"
		"Contacts"
		"Reminders"
		"Notes"
		"TV"
		"Music"
		"Keynote"
		"Numbers"
		"Pages"
		"Games"
		"App Store"
		"iPhone Mirroring"
		"System Settings"
	)

	# Common default Dock folders/stacks.
	local default_stacks=("Applications" "Downloads" "Recent Applications")

	if command -v dockutil >/dev/null 2>&1; then
		echo "Removing default macOS Dock items via dockutil..."
		for dock_item in "${default_apps[@]}"; do
			run_nonfatal dockutil --remove "$dock_item" --no-restart
		done
		for dock_stack in "${default_stacks[@]}"; do
			run_nonfatal dockutil --remove "$dock_stack" --no-restart
		done
	else
		echo "dockutil not found; clearing pinned Dock items via defaults fallback."
		run defaults write com.apple.dock persistent-apps -array
		run defaults write com.apple.dock persistent-others -array
	fi
}

echo "Applying Dock defaults..."

# Move the dock to the right side of the screen
run defaults write com.apple.dock orientation -string right

# Set the icon size
run defaults write com.apple.dock tilesize -int 36

# Enable auto-hide for the dock
run defaults write com.apple.dock autohide -bool true

# Remove the default macOS app set from Dock.
remove_default_dock_items

# Keyboard-first optional mode: show only currently running apps
if [ "$RUNNING_ONLY" -eq 1 ]; then
	run defaults write com.apple.dock static-only -bool true
	echo "Dock mode: running apps only"
else
	# Keep pinned apps visible (useful for profile-specific launchers)
	run defaults write com.apple.dock static-only -bool false
	echo "Dock mode: pinned + running apps"
fi

# Hide recently used apps in Dock
run defaults write com.apple.dock show-recents -bool false

# Restart Dock to apply (unless disabled)
if [ "$NO_RESTART" -eq 1 ]; then
	echo "Skipping Dock restart (--no-restart)."
elif [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: killall Dock"
else
	killall Dock >/dev/null 2>&1 || true
fi
echo "Dock defaults applied."
