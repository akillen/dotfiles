#!/bin/zsh

# --- Utility: Spinner ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

echo "🚀 Starting Mac Setup..."

# 1. Install Homebrew if it's not there
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add brew to path for the current session
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew already installed. Skipping..."
fi

# 2. Update Homebrew
echo "Updating Homebrew..."
brew update

# 3. Install everything from the Brewfile
echo "Installing apps from Brewfile..."
brew bundle --file=./Brewfile

# 4. Set macOS Defaults
echo "Applying macOS system settings..."
# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles YES

# Set the alert volume to 0 (This is the 'bonk/dink' sound)
defaults write com.apple.systemsound "com.apple.sound.beep.volume" -float 0

# --- Dock Customization ---

# Move the dock to the right side of the screen
defaults write com.apple.dock orientation -string right

# Set the icon size (tilesize). 36 is quite small; default is usually 64.
defaults write com.apple.dock tilesize -int 36

# Enable auto-hide for the dock
defaults write com.apple.dock autohide -bool true

# Wipe all app icons from the Dock (optional: if you want a clean slate)
# defaults write com.apple.dock persistent-apps -array

# IMPORTANT: You must restart the Dock for changes to take effect
killall Dock

# ... after the Brew bundle command ...

# 5. Gemini CLI Initial Setup
if command -v gemini &> /dev/null; then
    echo "🤖 Gemini CLI detected. To finish setup, run 'gemini' and sign in when prompted."
    # Optional: Open the auth URL immediately
    # gemini --auth
fi

# --- SSH Key Setup ---
echo "🔑 Checking for SSH keys..."

if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating new SSH key..."
    # Replace the email with your own or use a generic one
    ssh-keygen -t ed25519 -C "aaron.killen@lockerroomlabs.com" -f ~/.ssh/id_ed25519 -N ""
    
    # Start the ssh-agent in the background
    eval "$(ssh-agent -s)"
    
    # Add key to agent and store passphrase in keychain
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    
    # Copy to clipboard
    pbcopy < ~/.ssh/id_ed25519.pub
    echo "✅ New SSH key generated and copied to clipboard. Paste it into your Git provider!"
else
    echo "SSH key already exists. Skipping..."
fi

# --- Git Config ---
echo "⚙️ Configuring Git..."

git config --global user.name "Aaron"
git config --global user.email "aaron.killen@lockerroomlabs.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait" # Sets VS Code as your default editor for commits

# --- Symlinking ---
echo "🔗 Linking dotfiles..."

# This creates a symbolic link: ~/dotfiles/.zshrc -> ~/.zshrc
ln -sf ~/dotfiles/.zshrc ~/.zshrc

source ~/.zshrc

# --- iOS & Xcode Setup (Robust Edition) ---
echo "🛠️ Starting iOS Development environment setup..."

# 1. Install/Verify Xcode
if ! xcodes installed | grep -q "Select"; then
    echo "📥 Downloading and installing the latest Xcode..."
    xcodes install --latest --select & 
    spinner $!
    # Check if the last command (xcodes) actually succeeded
    if [ $? -ne 0 ]; then
        echo "\n❌ Error: Xcode installation failed. Check your internet or disk space."
        exit 1
    fi
    echo "\n✅ Xcode binary installed."
else
    echo "Xcode is already installed."
fi

# 2. Run First Launch (CRITICAL FIX)
# This installs the system frameworks that the error was complaining about.
echo "system-run: Initializing Xcode system components..."
sudo xcodebuild -runFirstLaunch

# 3. Finalize permissions
echo "⚖️ Accepting Xcode license..."
sudo xcodebuild -license accept

# 4. Install the iOS Simulator Runtime
echo "📲 Downloading latest iOS Simulator runtime..."
if sudo xcodebuild -downloadPlatform iOS & spinner $! ; then
    echo "\n✅ iOS Simulator is ready!"
else
    echo "\n❌ Error: Simulator download failed. Try running 'xcodebuild -runFirstLaunch' manually."
    exit 1
fi

echo "🔍 Current developer path: $(xcode-select -p)"

echo "✅ Setup complete! Note: Some changes may require a logout/restart."
