# Dotfiles zsh configuration

# Ensure Homebrew paths are loaded early.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# nvm initialization (Homebrew install path)
export NVM_DIR="$HOME/.nvm"
if command -v brew >/dev/null 2>&1; then
  _nvm_brew_prefix="$(brew --prefix nvm 2>/dev/null || true)"
  if [ -n "$_nvm_brew_prefix" ] && [ -s "$_nvm_brew_prefix/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$_nvm_brew_prefix/nvm.sh"
    if [ -s "$_nvm_brew_prefix/etc/bash_completion.d/nvm" ]; then
      # shellcheck disable=SC1091
      . "$_nvm_brew_prefix/etc/bash_completion.d/nvm"
    fi
  fi
fi

# Automatically switch Node versions based on .nvmrc when changing directories.
# This relies on zsh-specific hooks and should only run in zsh.
if [ -n "${ZSH_VERSION-}" ] && command -v nvm >/dev/null 2>&1; then
  autoload -U add-zsh-hook

  load-nvmrc() {
    local nvmrc_path requested_version resolved_version current_version default_version
    nvmrc_path="$(nvm_find_nvmrc 2>/dev/null || true)"

    if [ -n "$nvmrc_path" ]; then
      requested_version="$(cat "$nvmrc_path")"
      resolved_version="$(nvm version "$requested_version")"
      if [ "$resolved_version" = "N/A" ]; then
        nvm install "$requested_version" >/dev/null
      fi
      nvm use --silent "$requested_version" >/dev/null
    else
      default_version="$(nvm version default)"
      current_version="$(nvm version)"
      if [ "$default_version" != "N/A" ] && [ "$current_version" != "$default_version" ]; then
        nvm use --silent default >/dev/null
      fi
    fi
  }

  add-zsh-hook chpwd load-nvmrc
  load-nvmrc
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
