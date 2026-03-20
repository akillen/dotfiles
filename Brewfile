# NOTE: As of Homebrew changes, some taps (homebrew/bundle, homebrew/cask-fonts)
# are deprecated. Keep this Brewfile minimal and prefer core formulas/casks.

# -- Taps --
tap "wix/brew"

# -- CLI Tools (brew formulas) --
brew "git"
brew "gemini-cli"
brew "asdf"
brew "python"
brew "zsh-autosuggestions"
brew "tree"
brew "jq" # Great for processing JSON
brew "dialog" # Script dialogs/utilities
brew "watchman" # React Native file watching
brew "xcodes"
brew "cocoapods" # iOS dependency manager
brew "wix/brew/applesimutils" # iOS simulator management (Detox)
brew "duti" # set default handlers (e.g., default browser)
brew "dockutil" # explicit Dock item add/remove by app name
brew "mas" # Mac App Store CLI (use `mas install <id>` for store apps)

# -- Mac App Store Apps (mas) --
mas "Amphetamine", id: 937984704 # Sleep/wake scheduling utility

# -- GUI Apps (casks)
cask "visual-studio-code"
cask "iterm2"
cask "slack"
cask "microsoft-outlook"
cask "microsoft-teams"
cask "notion"
cask "zoom"
cask "docker-desktop"
cask "firefox"
cask "bitwarden"
cask "bruno" # API client (Postman alternative)
cask "postman" # API client
cask "google-drive" # Cloud sync client
cask "rectangle" # Window management

# -- Fonts (via homebrew/cask-fonts)
cask "font-fira-code" # Nice dev font

# Notes:
# - Group entries by type (taps / brew / cask / mas) so `brew bundle` stays readable.
# - Remove duplicates and comment optional items. Add mas-managed app IDs separately.
