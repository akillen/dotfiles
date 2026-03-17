#!/usr/bin/env bash
set -euo pipefail

# Disable macOS system/UI sounds while preserving multimedia audio.
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

echo "Applying sound defaults..."

# Mute the startup boot chime (requires sudo; nvram survives reboots).
# setup.sh pre-fetches and keeps sudo credentials alive, so no additional
# password prompt should be required here.
if [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: sudo nvram StartupMute=%01"
else
	sudo nvram StartupMute=%01
fi

# Disable the MagSafe/USB-C charging connection chime
run defaults write com.apple.PowerChime ChimeOnAllHardware -bool false

# Stop PowerChime process if running so the change takes effect immediately
if [ "$DRY_RUN" -eq 0 ]; then
	killall PowerChime >/dev/null 2>&1 || true
fi

# Disable UI audio (error beeps, alerts, system event sounds)
run defaults write com.apple.systemsound "com.apple.sound.uiaudio.enabled" -int 0

# Disable keyboard/click UI feedback sounds
run defaults write -g "com.apple.sound.beep.feedback" -int 0

# Set alert volume to zero as an additional fallback
run defaults write -g "com.apple.sound.beep.volume" -float 0

# Restart SystemUIServer to apply menu-bar / sound indicator changes
if [ "$NO_RESTART" -eq 1 ]; then
	echo "Skipping SystemUIServer restart (--no-restart)."
elif [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: killall -HUP SystemUIServer"
else
	killall -HUP SystemUIServer >/dev/null 2>&1 || true
fi

echo "Sound defaults applied."
