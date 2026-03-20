#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-node.sh [--dry-run] [--yes] [--node-version node] [--npm-version latest] [--global-packages "expo eas-cli detox-cli"]

DRY_RUN=0
ASSUME_YES=0
NODE_VERSION="node"
NPM_VERSION="latest"
GLOBAL_PACKAGES="expo eas-cli detox-cli"

while [[ ${1-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --node-version)
      shift
      NODE_VERSION="${1-}"
      ;;
    --npm-version)
      shift
      NPM_VERSION="${1-}"
      ;;
    --global-packages)
      shift
      GLOBAL_PACKAGES="${1-}"
      ;;
    -h|--help)
      sed -n '1,220p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# add_or_update_asdf_plugin NAME [URL]
#   Adds the plugin if it is not yet installed; updates it if it is.
#   Keeping the plugin up to date ensures 'asdf list all' sees new releases.
# ---------------------------------------------------------------------------
add_or_update_asdf_plugin() {
  local name="$1"
  local url="${2:-}"

  if ! asdf plugin list 2>/dev/null | grep -qx "$name"; then
    echo "Adding asdf $name plugin..."
    if [ -n "$url" ]; then
      asdf plugin add "$name" "$url"
    else
      asdf plugin add "$name"
    fi
  else
    echo "Updating asdf $name plugin..."
    asdf plugin update "$name"
  fi
}

# ---------------------------------------------------------------------------
# set_asdf_user_default LANGUAGE VERSION
#   Sets the user-level default version in a way that works across asdf
#   releases. asdf >= 0.16 uses 'asdf set -u'; older releases used
#   'asdf global'.
# ---------------------------------------------------------------------------
set_asdf_user_default() {
  local language="$1"
  local version="$2"

  if asdf set -u "$language" "$version" >/dev/null 2>&1; then
    echo "Set user default with: asdf set -u $language $version"
    return 0
  fi

  if asdf global "$language" "$version" >/dev/null 2>&1; then
    echo "Set user default with: asdf global $language $version"
    return 0
  fi

  echo "Failed to set default $language version ($version)."
  echo "Tried both 'asdf set -u' and 'asdf global'."
  return 1
}

# ---------------------------------------------------------------------------
# install_asdf_language LANGUAGE
#   Resolves the latest *stable* release (filters out alpha/beta/rc/nightly
#   versions by rejecting any tag that contains a letter), installs it if not
#   already present, and sets it as the user default.
# ---------------------------------------------------------------------------
install_asdf_language() {
  local language="$1"
  local version
  # grep -v "[a-zA-Z]" removes pre-release tags; tr + tail picks the last
  # (highest) numeric-only version string.
  version="$(asdf list all "$language" | grep -v "[a-zA-Z]" | tr -s '\n' | tail -1 | tr -d '[:space:]')"

  echo "Latest stable $language version: $version"

  if ! asdf list "$language" 2>/dev/null | grep -qF "$version"; then
    echo "Installing $language $version..."
    asdf install "$language" "$version"
  else
    echo "$language $version is already installed."
  fi

  echo "Setting $language $version as user default..."
  set_asdf_user_default "$language" "$version"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "Setting up Node.js with asdf..."

if ! command -v brew > /dev/null 2>&1; then
  echo "Homebrew is required before running setup-node.sh"
  exit 1
fi

# Resolve the asdf shell integration script from the Homebrew prefix.
ASDF_PREFIX="$(brew --prefix asdf 2>/dev/null || true)"
ASDF_SH="${ASDF_PREFIX}/libexec/asdf.sh"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: source '$ASDF_SH'"
  echo "DRY RUN: add_or_update_asdf_plugin nodejs"
  echo "DRY RUN: install_asdf_language nodejs  (or pin explicit version: $NODE_VERSION)"
  echo "DRY RUN: npm install -g 'npm@$NPM_VERSION'"
  if [ -n "$GLOBAL_PACKAGES" ]; then
    echo "DRY RUN: npm install -g $GLOBAL_PACKAGES"
  fi
  echo "DRY RUN: shell init is managed by your dotfiles .zshrc (no rc-file mutation)"
  return 0 2>/dev/null || exit 0
fi

if [ ! -f "$ASDF_SH" ]; then
  echo "asdf.sh not found at $ASDF_SH"
  echo "Ensure Brewfile has 'brew \"asdf\"' and brew bundle completed successfully."
  exit 1
fi

# shellcheck disable=SC1090
. "$ASDF_SH"

echo "Shell init is managed by dotfiles .zshrc; setup-node.sh will not edit rc files."

# Add / update the nodejs plugin.
add_or_update_asdf_plugin "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"

# Install Node — either the latest stable or an explicit pinned version.
if [ "$NODE_VERSION" = "node" ] || [ "$NODE_VERSION" = "latest" ]; then
  install_asdf_language "nodejs"
else
  echo "Installing Node.js $NODE_VERSION (explicit version)..."
  if ! asdf list nodejs 2>/dev/null | grep -qF "$NODE_VERSION"; then
    asdf install nodejs "$NODE_VERSION"
  else
    echo "Node.js $NODE_VERSION is already installed."
  fi
  echo "Setting Node.js $NODE_VERSION as user default..."
  set_asdf_user_default nodejs "$NODE_VERSION"
fi

# Verify node is on PATH.
if ! command -v node > /dev/null 2>&1; then
  echo "node not found on PATH after asdf setup."
  exit 1
fi

if command -v npm > /dev/null 2>&1; then
  npm install -g "npm@$NPM_VERSION"

  if [ -n "$GLOBAL_PACKAGES" ]; then
    # Space-delimited package list from config/CLI.
    read -r -a pkgs <<< "$GLOBAL_PACKAGES"
    npm install -g "${pkgs[@]}"
  fi
else
  echo "npm was not found after asdf setup."
  exit 1
fi

echo "Node version: $(node -v)"
echo "npm version: $(npm -v)"
if command -v npx > /dev/null 2>&1; then
  echo "npx version: $(npx --version)"
else
  echo "npx command not found (npm 10+ still supports 'npm exec')."
fi
