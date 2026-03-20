# Dotfiles zsh configuration

# Ensure Homebrew paths are loaded early.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# asdf initialization (Homebrew install path)
if command -v brew > /dev/null 2>&1; then
  _asdf_prefix="$(brew --prefix asdf 2>/dev/null || true)"
  if [ -n "$_asdf_prefix" ] && [ -f "$_asdf_prefix/libexec/asdf.sh" ]; then
    # shellcheck disable=SC1091
    . "$_asdf_prefix/libexec/asdf.sh"
  fi
fi

# Automatically switch Node versions based on .nvmrc when changing directories.
# asdf-nodejs respects .nvmrc (and .node-version) natively; this hook ensures
# the correct version is installed and activated whenever the directory changes.
if [ -n "${ZSH_VERSION-}" ] && command -v asdf > /dev/null 2>&1; then
  autoload -U add-zsh-hook

  _asdf_load_nvmrc() {
    local nvmrc_path
    nvmrc_path="${PWD}/.nvmrc"

    if [ -f "$nvmrc_path" ]; then
      local requested_version
      requested_version="$(cat "$nvmrc_path")"
      # Install the version if it is not yet available.
      if ! asdf list nodejs 2>/dev/null | grep -qF "$requested_version"; then
        asdf install nodejs "$requested_version"
      fi
      asdf set --local nodejs "$requested_version" 2>/dev/null || \
        ASDF_NODEJS_VERSION="$requested_version"
    else
      # No .nvmrc — restore the global default.
      unset ASDF_NODEJS_VERSION
    fi
  }

  add-zsh-hook chpwd _asdf_load_nvmrc
  _asdf_load_nvmrc
fi

# Optional machine-local shell customizations
if [ -f "$HOME/.zshrc.local" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.zshrc.local"
fi
