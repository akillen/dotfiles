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

usage() {
  cat <<USAGE
Usage: $PROG_NAME [--dry-run] [--yes] [--config path] [--name "Full Name"] [--email "you@example.com"] [--no-source] [--no-restart]

Options:
  --dry-run     Show actions without making changes
  --yes         Assume yes for prompts (use with care)
  --config      Path to setup config file (default: ./setup.conf)
  --name        Git user.name to configure
  --email       Git user.email and used for SSH key generation
  --no-source   Do not source the new shell config at the end
  --no-restart  Do not restart Finder/Dock after defaults changes
  --skip-xcode  Skip Xcode toolchain setup steps
  --skip-simulator  Skip iOS simulator runtime download
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
    --skip-xcode) SKIP_XCODE=1 ;;
    --skip-simulator) SKIP_SIMULATOR=1 ;;
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

load_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

set_handler_with_retry() {
  local bundle_id="$1"
  local target="$2"
  local attempts="${3:-15}"
  local sleep_seconds="${4:-2}"
  local attempt

  for ((attempt=1; attempt<=attempts; attempt++)); do
    if duti -s "$bundle_id" "$target" >/dev/null 2>&1; then
      echo "Set handler: $target -> $bundle_id"
      return 0
    fi

    if [ "$attempt" -eq 1 ]; then
      echo "Waiting for macOS default-browser confirmation to finish..."
    fi

    if [ "$attempt" -lt "$attempts" ]; then
      sleep "$sleep_seconds"
    fi
  done

  echo "Warning: failed to set handler for $target after $attempts attempts."
  return 1
}

configure_firefox_default() {
  if ! command -v duti >/dev/null 2>&1; then
    echo "duti not available; skipping default browser configuration."
    return 0
  fi

  if [ ! -d "/Applications/Firefox.app" ] && [ ! -d "$HOME/Applications/Firefox.app" ]; then
    echo "Firefox not installed; skipping default browser configuration."
    return 0
  fi

  echo "Registering Firefox with LaunchServices..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: open -a Firefox"
    echo "DRY RUN: duti -s org.mozilla.firefox http"
    echo "DRY RUN: duti -s org.mozilla.firefox https"
    echo "DRY RUN: duti -s org.mozilla.firefox public.html"
    echo "DRY RUN: duti -s org.mozilla.firefox .html"
    return 0
  fi

  # This can trigger the Firefox default-browser prompt.
  open -a "Firefox" >/dev/null 2>&1 || true
  echo "If prompted, choose Firefox as default. Waiting up to ~30 seconds for selection..."

  local ff_bundle="org.mozilla.firefox"
  local failures=0

  for target in http https public.html .html; do
    if ! set_handler_with_retry "$ff_bundle" "$target" 15 2; then
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

echo "Starting Mac setup..."

install_homebrew_if_missing
load_brew_env

echo "Updating Homebrew..."
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: brew update"
else
  brew update || true
fi

echo "Installing apps from Brewfile (from $SCRIPT_DIR)..."
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: brew bundle --file=$SCRIPT_DIR/Brewfile"
else
  brew bundle --file="$SCRIPT_DIR/Brewfile"
fi

configure_firefox_default

echo "Running modular setup scripts..."
common_flags=()
if [ "$DRY_RUN" -eq 1 ]; then common_flags+=(--dry-run); fi
if [ "$ASSUME_YES" -eq 1 ]; then common_flags+=(--yes); fi

echo "-> Symlinking dotfiles"
"$SCRIPT_DIR/scripts/symlink-dotfiles.sh" "${common_flags[@]}"

echo "-> Configuring Git"
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  "$SCRIPT_DIR/scripts/setup-git.sh" "${common_flags[@]}" --name "$GIT_NAME" --email "$GIT_EMAIL"
else
  echo "Git name/email not provided; skipping git identity setup."
fi

echo "-> Setting up SSH keys"
if [ -n "$GIT_EMAIL" ]; then
  "$SCRIPT_DIR/scripts/setup-ssh.sh" "${common_flags[@]}" --email "$GIT_EMAIL"
else
  echo "Email not provided; skipping SSH key generation."
fi

echo "-> Setting up Xcode toolchain"
if [ "$SKIP_XCODE" -eq 1 ]; then
  echo "Skipping Xcode setup (--skip-xcode)."
else
  xcode_flags=("${common_flags[@]}")
  if [ "$SKIP_SIMULATOR" -eq 1 ]; then xcode_flags+=(--skip-simulator); fi
  "$SCRIPT_DIR/scripts/setup-xcode.sh" "${xcode_flags[@]}"
fi

echo "-> Applying macOS defaults (Finder & Dock)"
defaults_flags=("${common_flags[@]}")
if [ "$NO_RESTART" -eq 1 ]; then defaults_flags+=(--no-restart); fi
"$SCRIPT_DIR/scripts/defaults-finder.sh" "${defaults_flags[@]}"
"$SCRIPT_DIR/scripts/defaults-dock.sh" "${defaults_flags[@]}"

if [ "$NO_SOURCE" -eq 0 ]; then
  if [ -f "$HOME/.zshrc" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY RUN: source $HOME/.zshrc"
    else
      echo "Sourcing ~/.zshrc"
      # shellcheck disable=SC1090
      source "$HOME/.zshrc" || true
    fi
  fi
fi

echo "Setup complete. Some changes may require logout/restart."
exit 0
