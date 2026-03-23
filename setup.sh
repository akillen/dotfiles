#!/usr/bin/env bash
set -euo pipefail

PROG_NAME="setup.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
CONFIG_FILE="$SCRIPT_DIR/setup.conf"

DRY_RUN=0
ASSUME_YES=0
GIT_NAME=""
GIT_EMAIL=""
NO_SOURCE=0
NO_RESTART=0
SKIP_XCODE=0
SKIP_SIMULATOR=0
SKIP_BROWSER_DEFAULT=0
SKIP_NODE_SETUP=0
SKIP_WORK_APPS=0
PROFILE="work"
DOCK_RUNNING_ONLY=0
NODE_VERSION="node"
NPM_VERSION="latest"
NPM_GLOBAL_PACKAGES="expo eas-cli detox-cli"
BROWSER_RETRY_ATTEMPTS=4
BROWSER_RETRY_DELAY_SECONDS=1
DEVELOPMENT_DIR="$HOME/development"
GOOGLE_DRIVE_ACCOUNT_EMAIL=""

usage() {
  cat <<USAGE
Usage: $PROG_NAME [--dry-run] [--yes] [--config path] [--profile work|personal] [--name "Full Name"] [--email "you@example.com"] [--no-source] [--no-restart]

Options:
  --dry-run     Show actions without making changes
  --yes         Assume yes for prompts (use with care)
  --config      Path to setup config file (default: ./setup.conf)
  --profile     Machine profile overlay to apply: work or personal
  --name        Git user.name to configure
  --email       Git user.email and used for SSH key generation
  --no-source   Do not source the new shell config at the end
  --no-restart  Do not restart Finder/Dock after defaults changes
  --dock-running-only  Dock shows only currently running apps (hides pinned apps)
  --skip-node   Skip Node.js/asdf setup
  --skip-xcode  Skip Xcode toolchain setup steps
  --skip-simulator  Skip iOS simulator runtime download
  --skip-browser-default  Skip Firefox default-browser configuration
  --skip-work-apps  Legacy override: skip work profile overlay (Brewfile.work)
USAGE
}

load_config_if_present() {
  local file="$1"
  if [ -f "$file" ]; then
    echo "Loading setup config from $file"
    # shellcheck disable=SC1090
    source "$file"
  else
    echo "No setup config at $file (using defaults/flags)."
  fi
}

ARGS=("$@")

# Pass 1: resolve config path early so file values can become defaults.
for ((i=0; i<${#ARGS[@]}; i++)); do
  case "${ARGS[$i]}" in
    --config)
      i=$((i + 1))
      if [ "$i" -ge "${#ARGS[@]}" ]; then
        echo "Missing value for --config"
        usage
        exit 1
      fi
      CONFIG_FILE="${ARGS[$i]}"
      ;;
  esac
done

load_config_if_present "$CONFIG_FILE"

# Pass 2: CLI flags override config defaults.
for ((i=0; i<${#ARGS[@]}; i++)); do
  case "${ARGS[$i]}" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --config)
      i=$((i + 1))
      ;;
    --profile)
      i=$((i + 1))
      if [ "$i" -ge "${#ARGS[@]}" ]; then
        echo "Missing value for --profile"
        usage
        exit 1
      fi
      PROFILE="${ARGS[$i]}"
      ;;
    --name)
      i=$((i + 1))
      if [ "$i" -ge "${#ARGS[@]}" ]; then
        echo "Missing value for --name"
        usage
        exit 1
      fi
      GIT_NAME="${ARGS[$i]}"
      ;;
    --email)
      i=$((i + 1))
      if [ "$i" -ge "${#ARGS[@]}" ]; then
        echo "Missing value for --email"
        usage
        exit 1
      fi
      GIT_EMAIL="${ARGS[$i]}"
      ;;
    --no-source) NO_SOURCE=1 ;;
    --no-restart) NO_RESTART=1 ;;
    --dock-running-only) DOCK_RUNNING_ONLY=1 ;;
    --skip-node) SKIP_NODE_SETUP=1 ;;
    --skip-xcode) SKIP_XCODE=1 ;;
    --skip-simulator) SKIP_SIMULATOR=1 ;;
    --skip-browser-default) SKIP_BROWSER_DEFAULT=1 ;;
    --skip-work-apps) SKIP_WORK_APPS=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${ARGS[$i]}"
      usage
      exit 1
      ;;
  esac
done

PROFILE="$(printf '%s' "$PROFILE" | tr '[:upper:]' '[:lower:]')"
case "$PROFILE" in
  work|personal) ;;
  *)
    echo "Invalid profile: $PROFILE"
    echo "Expected one of: work, personal"
    exit 1
    ;;
esac

install_homebrew_if_missing() {
  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew already installed."
    return 0
  fi

  echo "Installing Homebrew..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    return 0
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools already installed."
    return 0
  fi

  echo "Xcode Command Line Tools are required for iOS/native tooling."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: xcode-select --install"
    return 0
  fi

  xcode-select --install >/dev/null 2>&1 || true
  echo "Started Command Line Tools installer. Complete it, then rerun ./setup.sh."
  exit 1
}

load_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

current_handler_bundle_for_scheme() {
  local scheme="$1"
  local out
  out="$(duti -x "$scheme" 2>/dev/null || true)"
  printf '%s\n' "$out" | awk 'NR==3 {print $1}'
}

is_firefox_default_for_web() {
  local ff_bundle="org.mozilla.firefox"
  local http_bundle
  local https_bundle

  http_bundle="$(current_handler_bundle_for_scheme http)"
  https_bundle="$(current_handler_bundle_for_scheme https)"

  [ "$http_bundle" = "$ff_bundle" ] && [ "$https_bundle" = "$ff_bundle" ]
}

set_handler_with_retry() {
  local bundle_id="$1"
  local target="$2"
  local attempts="${3:-$BROWSER_RETRY_ATTEMPTS}"
  local sleep_seconds="${4:-$BROWSER_RETRY_DELAY_SECONDS}"
  local attempt
  local output
  local current

  for ((attempt=1; attempt<=attempts; attempt++)); do
    if output="$(duti -s "$bundle_id" "$target" 2>&1)"; then
      echo "Set handler: $target -> $bundle_id"
      return 0
    fi

    # Sometimes LaunchServices updates even when duti returns an error.
    current="$(current_handler_bundle_for_scheme "$target")"
    if [ "$current" = "$bundle_id" ]; then
      echo "Set handler: $target -> $bundle_id (verified)"
      return 0
    fi

    if [[ "$output" == *"error -54"* ]]; then
      if [ "$attempt" -lt "$attempts" ]; then
        echo "Browser-preference lock (error -54). Retrying $target ($attempt/$attempts)..."
      else
        echo "Browser-preference lock still active for $target; continuing without blocking setup."
      fi
    elif [ "$attempt" -eq "$attempts" ]; then
      echo "Last duti error for $target: $output"
    else
      echo "Retrying handler update for $target ($attempt/$attempts)..."
    fi

    if [ "$attempt" -lt "$attempts" ]; then
      sleep "$sleep_seconds"
    fi
  done

  echo "Warning: failed to set handler for $target after $attempts attempts."
  return 1
}

configure_firefox_default() {
  if [ "$SKIP_BROWSER_DEFAULT" -eq 1 ]; then
    echo "Skipping Firefox default-browser configuration (--skip-browser-default)."
    return 0
  fi

  if ! command -v duti >/dev/null 2>&1; then
    echo "duti not available; skipping default browser configuration."
    return 0
  fi

  if [ ! -d "/Applications/Firefox.app" ] && [ ! -d "$HOME/Applications/Firefox.app" ]; then
    echo "Firefox not installed; skipping default browser configuration."
    return 0
  fi

  if is_firefox_default_for_web; then
    echo "Firefox is already default for http/https; skipping browser update."
    return 0
  fi

  echo "Configuring Firefox as default for web links..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: duti -s org.mozilla.firefox http"
    echo "DRY RUN: duti -s org.mozilla.firefox https"
    return 0
  fi

  local ff_bundle="org.mozilla.firefox"
  local failures=0

  for target in http https; do
    if ! set_handler_with_retry "$ff_bundle" "$target"; then
      failures=$((failures + 1))
    fi
  done

  if [ "$failures" -eq 0 ]; then
    echo "Firefox default handler configuration complete."
  else
    echo "Warning: Firefox default configuration was partially applied."
    echo "You can retry later with: duti -s org.mozilla.firefox http && duti -s org.mozilla.firefox https"
  fi
}

is_google_drive_installed() {
  [ -d "/Applications/Google Drive.app" ] || [ -d "$HOME/Applications/Google Drive.app" ]
}

configure_google_drive_notice() {
  if ! is_google_drive_installed; then
    echo "Google Drive not installed; skipping Google Drive sign-in notice."
    return 0
  fi

  if [ -n "$GOOGLE_DRIVE_ACCOUNT_EMAIL" ]; then
    echo "Google Drive installed. Sign in to the app using: $GOOGLE_DRIVE_ACCOUNT_EMAIL"
    echo "Note: automated credential preconfiguration is not supported (OAuth login is app-driven)."
  else
    echo "Google Drive installed. Complete sign-in on first launch (OAuth login is app-driven)."
  fi
}

install_profile_overlay() {
  local profile_brewfile="$SCRIPT_DIR/Brewfile.$PROFILE"

  if [ "$PROFILE" = "work" ] && [ "$SKIP_WORK_APPS" -eq 1 ]; then
    echo "Skipping work profile overlay (--skip-work-apps)."
    return 0
  fi

  if [ ! -f "$profile_brewfile" ]; then
    echo "No profile overlay found for '$PROFILE' at $profile_brewfile; skipping."
    return 0
  fi

  echo "Installing profile overlay from $profile_brewfile..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: brew bundle --file=$profile_brewfile"
  else
    brew bundle --file="$profile_brewfile"
  fi
}

run_preflight_checks() {
  local guard_script="$SCRIPT_DIR/scripts/check-zshrc-portability.sh"
  local repo_zshrc="$SCRIPT_DIR/.zshrc"

  if [ ! -x "$guard_script" ]; then
    echo "Missing executable preflight guard: $guard_script"
    exit 1
  fi

  "$guard_script" "$repo_zshrc"
}

run_module_script() {
  local script_path="$1"
  shift

  if [ "$DRY_RUN" -eq 1 ] && [ "$ASSUME_YES" -eq 1 ]; then
    "$script_path" --dry-run --yes "$@"
  elif [ "$DRY_RUN" -eq 1 ]; then
    "$script_path" --dry-run "$@"
  elif [ "$ASSUME_YES" -eq 1 ]; then
    "$script_path" --yes "$@"
  else
    "$script_path" "$@"
  fi
}

install_rosetta_if_needed() {
  if [ "$(uname -m)" != "arm64" ]; then
    echo "Intel Mac detected; Rosetta not required."
    return 0
  fi

  if pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    echo "Rosetta 2 already installed."
    return 0
  fi

  echo "Installing Rosetta 2 (required for x86_64 compatibility on Apple Silicon)..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: softwareupdate --install-rosetta --agree-to-license"
    return 0
  fi

  softwareupdate --install-rosetta --agree-to-license
}

ensure_development_dir() {
  if [ -d "$DEVELOPMENT_DIR" ]; then
    echo "Development directory exists at $DEVELOPMENT_DIR"
    return 0
  fi

  echo "Creating development directory at $DEVELOPMENT_DIR"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: mkdir -p $DEVELOPMENT_DIR"
  else
    mkdir -p "$DEVELOPMENT_DIR"
  fi
}

request_sudo_upfront() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: sudo -v (credential prefetch)"
    return 0
  fi

  echo "Some steps require administrator privileges. Please enter your password now."
  echo "Note: a few pkg-based cask installers (e.g. Zoom, Outlook) use Apple's"
  echo "      Authorization Services and may prompt again — this is a macOS limitation."
  sudo -v

  # Keep the sudo credential alive for the duration of setup.
  ( while true; do sudo -n true; sleep 55; done ) &
  SUDO_KEEPALIVE_PID=$!
  # Ensure the keepalive is killed when setup exits (success or failure).
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

echo "Starting Mac setup..."

echo "Running preflight checks..."
run_preflight_checks

request_sudo_upfront
ensure_xcode_clt
install_rosetta_if_needed
install_homebrew_if_missing
load_brew_env

echo "Updating Homebrew..."
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: brew update"
else
  brew update || true
fi

echo "Ensuring required taps..."
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: brew tap wix/brew"
else
  brew tap wix/brew >/dev/null 2>&1 || brew tap wix/brew
fi

echo "Installing apps from Brewfile (from $SCRIPT_DIR)..."
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: brew bundle --file=$SCRIPT_DIR/Brewfile"
else
  brew bundle --file="$SCRIPT_DIR/Brewfile"
fi

install_profile_overlay

configure_firefox_default
configure_google_drive_notice

ensure_development_dir

echo "Running modular setup scripts..."

echo "-> Symlinking dotfiles"
run_module_script "$SCRIPT_DIR/scripts/symlink-dotfiles.sh"

echo "-> Setting up Node.js (asdf + npm + npx)"
if [ "$SKIP_NODE_SETUP" -eq 1 ]; then
  echo "Skipping Node setup (--skip-node)."
else
  run_module_script "$SCRIPT_DIR/scripts/setup-node.sh" --node-version "$NODE_VERSION" --npm-version "$NPM_VERSION" --global-packages "$NPM_GLOBAL_PACKAGES"
fi

echo "-> Configuring Git"
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  run_module_script "$SCRIPT_DIR/scripts/setup-git.sh" --name "$GIT_NAME" --email "$GIT_EMAIL"
else
  echo "Git name/email not provided; skipping git identity setup."
fi

echo "-> Setting up SSH keys"
if [ -n "$GIT_EMAIL" ]; then
  run_module_script "$SCRIPT_DIR/scripts/setup-ssh.sh" --email "$GIT_EMAIL"
else
  echo "Email not provided; skipping SSH key generation."
fi

echo "-> Setting up mitmproxy certificate trust"
run_module_script "$SCRIPT_DIR/scripts/setup-mitmproxy.sh"

echo "-> Setting up Xcode toolchain"
if [ "$SKIP_XCODE" -eq 1 ]; then
  echo "Skipping Xcode setup (--skip-xcode)."
else
  if [ "$SKIP_SIMULATOR" -eq 1 ]; then
    run_module_script "$SCRIPT_DIR/scripts/setup-xcode.sh" --skip-simulator
  else
    run_module_script "$SCRIPT_DIR/scripts/setup-xcode.sh"
  fi
fi

echo "-> Applying macOS defaults (Finder, Trackpad, Dock, Sound & Menu Bar)"
if [ "$NO_RESTART" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-finder.sh" --no-restart
else
  run_module_script "$SCRIPT_DIR/scripts/defaults-finder.sh"
fi

if [ "$NO_RESTART" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-trackpad.sh" --no-restart
else
  run_module_script "$SCRIPT_DIR/scripts/defaults-trackpad.sh"
fi

if [ "$NO_RESTART" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-sounds.sh" --no-restart
else
  run_module_script "$SCRIPT_DIR/scripts/defaults-sounds.sh"
fi

if [ "$NO_RESTART" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-menubar.sh" --no-restart
else
  run_module_script "$SCRIPT_DIR/scripts/defaults-menubar.sh"
fi

if [ "$NO_RESTART" -eq 1 ] && [ "$DOCK_RUNNING_ONLY" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-dock.sh" --no-restart --running-only
elif [ "$NO_RESTART" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-dock.sh" --no-restart
elif [ "$DOCK_RUNNING_ONLY" -eq 1 ]; then
  run_module_script "$SCRIPT_DIR/scripts/defaults-dock.sh" --running-only
else
  run_module_script "$SCRIPT_DIR/scripts/defaults-dock.sh"
fi

if [ "$NO_SOURCE" -eq 0 ]; then
  if [ -f "$HOME/.zshrc" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY RUN: source $HOME/.zshrc"
    else
      if [ -n "${ZSH_VERSION-}" ]; then
        echo "Sourcing ~/.zshrc"
        # shellcheck disable=SC1090
        source "$HOME/.zshrc" || true
      else
        echo "Skipping auto-source of ~/.zshrc from non-zsh shell."
        echo "Open a new terminal or run: exec zsh"
      fi
    fi
  fi
fi

# Run per-machine local customizations if present.
# Create ~/setup.local to add steps that are not appropriate for the shared
# repo (e.g. work-specific tool installs, license keys, personal aliases).
# This file is never committed — it is the setup-script equivalent of .zshrc.local.
if [ -f "$HOME/setup.local" ]; then
  echo "-> Running local customizations from ~/setup.local"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: source $HOME/setup.local"
  else
    # shellcheck disable=SC1090
    source "$HOME/setup.local"
  fi
fi

echo "Setup complete. Some changes may require logout/restart."
exit 0
