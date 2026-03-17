#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-xcode.sh [--dry-run] [--yes] [--skip-simulator]
#
# Handles long-running Xcode setup steps with a terminal spinner so progress
# remains visible while commands run in the background.

DRY_RUN=0
ASSUME_YES=0
SKIP_SIMULATOR=0

while [[ ${1-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --skip-simulator) SKIP_SIMULATOR=1 ;;
    -h|--help)
      sed -n '1,240p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

spinner_wait() {
  local pid="$1"
  local label="$2"
  local spin='|/-\\'
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + 1) % 4))
    printf "\r%s [%c]" "$label" "${spin:$i:1}"
    sleep 0.2
  done

  wait "$pid"
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    printf "\r%s [done]\n" "$label"
  else
    printf "\r%s [failed]\n" "$label"
  fi
  return "$rc"
}

run_with_spinner() {
  local label="$1"
  shift

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: $*"
    return 0
  fi

  local log_file
  log_file="$(mktemp -t setup-xcode.XXXXXX.log)"

  "$@" >"$log_file" 2>&1 &
  local pid=$!

  if ! spinner_wait "$pid" "$label"; then
    echo "Command failed: $*"
    echo "Last output lines:"
    tail -n 60 "$log_file" || true
    rm -f "$log_file"
    return 1
  fi

  rm -f "$log_file"
}

ensure_sudo() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: sudo -v"
    return 0
  fi

  echo "Refreshing sudo credentials..."
  sudo -v
}

echo "Starting Xcode setup..."

if ! command -v xcodes >/dev/null 2>&1; then
  echo "xcodes is not installed; skipping Xcode setup."
  exit 0
fi

if xcodes installed 2>/dev/null | grep -qi "selected"; then
  echo "Xcode already installed and selected."
else
  run_with_spinner "Installing latest Xcode (this may take a while)" xcodes install --latest --select
fi

ensure_sudo

run_with_spinner "Running xcodebuild first launch" sudo -n xcodebuild -runFirstLaunch
run_with_spinner "Accepting Xcode license" sudo -n xcodebuild -license accept

if [ "$SKIP_SIMULATOR" -eq 0 ]; then
  run_with_spinner "Downloading iOS simulator runtime" sudo -n xcodebuild -downloadPlatform iOS
else
  echo "Skipping iOS simulator runtime download (--skip-simulator)."
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: xcode-select -p"
else
  echo "Current developer path: $(xcode-select -p)"
fi

echo "Xcode setup complete."
