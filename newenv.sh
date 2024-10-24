#!/bin/bash

# Exit on error
set -e

echo "Starting macOS development environment setup..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew already installed, updating..."
    brew update
fi

# Install Fish shell
echo "Installing Fish shell..."
brew install fish

# Change default shell to Fish
FISH_PATH=$(which fish)
if ! grep -q $FISH_PATH /etc/shells; then
    echo "Adding Fish to allowed shells..."
    echo $FISH_PATH | sudo tee -a /etc/shells
fi

# Change default shell to Fish only if it's not already the default
if ! dscl . -read ~/ UserShell | grep -q "$FISH_PATH"; then
    echo "Changing default shell to Fish..."
    chsh -s "$FISH_PATH"
else
    echo "Fish is already the default shell, skipping..."
fi

# Clone dotfiles repo (replace URL with your actual dotfiles repo)
DOTFILES_REPO="https://github.com/nateberkopec/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles repository..."
    git clone $DOTFILES_REPO $DOTFILES_DIR
else
    echo "Dotfiles directory already exists, pulling latest changes..."
    cd $DOTFILES_DIR
    git pull
fi

# Copy Fish config
echo "Setting up Fish configuration..."
mkdir -p ~/.config/fish
cp $DOTFILES_DIR/fish/config.fish ~/.config/fish/
cp -R $DOTFILES_DIR/fish/functions ~/.config/fish/ 2>/dev/null || true

# Install oh-my-fish if not present
if [ ! -d "$HOME/.local/share/omf" ]; then
    echo "Installing oh-my-fish..."
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install
    fish -c "fish install --noninteractive"
    rm install
else
    echo "oh-my-fish already installed, skipping..."
fi

# Set up omf configuration
echo "Configuring oh-my-fish..."
mkdir -p ~/.config/omf
cp -r "$DOTFILES_DIR/omf/"* ~/.config/omf/

# Install the theme and plugins from bundle
fish -c "omf install"

# Open/install fonts
find ~/.dotfiles/fonts -type f \( -name "*.ttf" -o -name "*.otf" \) -exec open {} \;

echo "Installing zoxide..."
brew install zoxide

# Install and configure iTerm2
echo "Installing iTerm2..."
brew install --cask iterm2

# Copy iTerm2 preferences
echo "Configuring iTerm2..."
cp $DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist ~/Library/Preferences/

# Install Arc browser if not already installed
if [ ! -d "/Applications/Arc.app" ]; then
    echo "Installing Arc browser..."
    brew install --cask arc
else
    echo "Arc browser is already installed, skipping..."
fi

# Install Amethyst
echo "Installing Amethyst window manager..."
brew install --cask amethyst

echo "Configuring Amethyst..."
cp $DOTFILES_DIR/amethyst/com.amethyst.Amethyst.plist  ~/Library/Preferences/

# Install GitHub Desktop
echo "Installing GitHub Desktop..."
brew install --cask github

# Copy Git global configuration
echo "Configuring Git global settings..."
cp $DOTFILES_DIR/git/.gitconfig ~/.gitconfig

# Install Visual Studio Code
echo "Installing Visual Studio Code..."
brew install --cask visual-studio-code

# Copy VSCode settings
echo "Configuring VSCode..."
mkdir -p ~/Library/Application\ Support/Code/User
cp $DOTFILES_DIR/vscode/settings.json ~/Library/Application\ Support/Code/User/
cp $DOTFILES_DIR/vscode/keybindings.json ~/Library/Application\ Support/Code/User/

# Install VSCode extensions from file if it exists
if [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
    echo "Installing VSCode extensions..."
    while IFS= read -r extension; do
        code --install-extension "$extension"
    done < "$DOTFILES_DIR/vscode/extensions.txt"
fi

echo "Installing Alfred 5..."
brew install --cask alfred

echo "Configuring Alfred..."
cp $DOTFILES_DIR/alfred/*  ~/Library/Preferences/

echo "Installing asdf..."
brew install asdf

echo "Installing direnv..."
brew install direnv

# Install asdf if not already installed
if ! command -v asdf &> /dev/null; then
    echo "Installing asdf..."
    brew install asdf

    # Add to Fish config (create file if it doesn't exist)
    mkdir -p ~/.config/fish/conf.d
    echo "source $(brew --prefix asdf)/libexec/asdf.fish" > ~/.config/fish/conf.d/asdf.fish
else
    echo "asdf already installed, skipping..."
fi

# Add Ruby plugin if not already added
if ! asdf plugin list | grep -q "ruby"; then
    echo "Adding Ruby plugin to asdf..."
    asdf plugin add ruby
fi

# Install latest stable Ruby
echo "Installing latest stable Ruby..."
latest_ruby=$(asdf latest ruby)
asdf install ruby $latest_ruby
asdf global ruby $latest_ruby

echo "Installation complete! Please restart your terminal for all changes to take effect."
echo "Note: You may need to manually set your iTerm2 theme through the preferences menu."
