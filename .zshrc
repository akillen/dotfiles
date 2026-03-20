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
# This is runtime-only (no project file mutation): it exports
# ASDF_NODEJS_VERSION for the current shell.
if [ -n "${ZSH_VERSION-}" ] && command -v asdf > /dev/null 2>&1; then
  autoload -U add-zsh-hook

  _asdf_load_nvmrc() {
    local nvmrc_path
    local requested_version
    nvmrc_path="${PWD}/.nvmrc"

    if [ -f "$nvmrc_path" ]; then
      requested_version="$(tr -d '[:space:]' < "$nvmrc_path")"
      # nvmrc often uses a leading "v" (e.g. v22.18.0); asdf expects plain semver.
      requested_version="${requested_version#v}"

      if [ -z "$requested_version" ]; then
        unset ASDF_NODEJS_VERSION
        return 0
      fi

      # Install the version if it is not yet available.
      if ! asdf list nodejs 2>/dev/null | sed 's/^[*[:space:]]*//' | grep -qxF "$requested_version"; then
        asdf install nodejs "$requested_version"
      fi

      # asdf 0.18 removed "asdf local"; use runtime env var for per-directory behavior.
      export ASDF_NODEJS_VERSION="$requested_version"
    else
      # No .nvmrc — restore the global default.
      unset ASDF_NODEJS_VERSION
    fi
  }

  add-zsh-hook chpwd _asdf_load_nvmrc
  _asdf_load_nvmrc
fi

# Prompt settings
function parse_git_branch() {
  git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/[\1]/p'
}

COLOR_DEF=$'%f'
COLOR_USR=$'%F{243}'
COLOR_DIR=$'%F{194}'
COLOR_GIT=$'%F{39}'
setopt PROMPT_SUBST
export PROMPT='${COLOR_USR}%n ${COLOR_DIR}%2/ ${COLOR_GIT}$(parse_git_branch)${COLOR_DEF} $ '

# Optional machine-local shell customizations
if [ -f "$HOME/.zshrc.local" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.zshrc.local"
fi
