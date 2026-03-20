# NOTE: As of Homebrew changes, some taps (homebrew/bundle, homebrew/cask-fonts)
# are deprecated. Keep this Brewfile minimal and prefer core formulas/casks.

# -- Taps --
tap "wix/brew"

# -- CLI Tools (brew formulas) --
brew "asdf"
brew "cocoapods" # iOS dependency manager
brew "dialog" # Script dialogs/utilities
brew "dockutil" # explicit Dock item add/remove by app name
brew "duti" # set default handlers (e.g., default browser)
brew "gemini-cli"
brew "git"
brew "jq" # Great for processing JSON
brew "mas" # Mac App Store CLI (use `mas install <id>` for store apps)
brew "python"
brew "tree"
brew "watchman" # React Native file watching
brew "wix/brew/applesimutils" # iOS simulator management (Detox)
brew "xcodes"
brew "zsh-autosuggestions"

# -- Mac App Store Apps (mas) --
mas "Amphetamine", id: 937984704 # Sleep/wake scheduling utility

# -- GUI Apps (casks)
cask "bitwarden"
cask "bruno" # API client (Postman alternative)
cask "docker-desktop"
cask "firefox"
cask "google-drive" # Cloud sync client
cask "grandperspective"
cask "iterm2"
cask "mitmproxy" # Intercept HTTP/HTTPS traffic for debugging
cask "notion"
cask "postman" # API client
cask "rectangle" # Window management
cask "slack"
cask "visual-studio-code"

# -- Fonts (via homebrew/cask-fonts)
cask "font-fira-code" # Nice dev font

# Notes:
# - Group entries by type (taps / brew / cask / mas) so `brew bundle` stays readable.
# - Remove duplicates and comment optional items. Add mas-managed app IDs separately.
