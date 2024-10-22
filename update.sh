#!/bin/bash

# Exit on error
set -e

DOTFILES_DIR="$HOME/.dotfiles"

# Check if dotfiles directory exists
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Error: Dotfiles directory not found at $DOTFILES_DIR"
    echo "Please run the initial setup script first."
    exit 1
fi

echo "Updating dotfiles repository..."

# Function to backup a file if it exists and has changed
backup_if_changed() {
    local source=$1
    local dest=$2
    
    if [ -f "$source" ]; then
        if [ ! -f "$dest" ] || ! cmp -s "$source" "$dest"; then
            echo "Updating $(basename "$dest")..."
            cp "$source" "$dest"
            return 0  # File was updated
        fi
    fi
    return 1  # File was not updated
}

# Track if any changes were made
changes_made=false

# Update Fish configurations
if backup_if_changed "$HOME/.config/fish/config.fish" "$DOTFILES_DIR/fish/config.fish"; then
    changes_made=true
fi

# Update Fish functions
if [ -d "$HOME/.config/fish/functions" ]; then
    echo "Checking Fish functions..."
    if rsync -a --delete --checksum "$HOME/.config/fish/functions/" "$DOTFILES_DIR/fish/functions/" 2>/dev/null; then
        changes_made=true
    fi
fi

# Update iTerm2 preferences
if backup_if_changed "$HOME/Library/Preferences/com.googlecode.iterm2.plist" "$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist"; then
    changes_made=true
fi

# Update VSCode settings
VSCODE_DIR="$HOME/Library/Application Support/Code/User"
if backup_if_changed "$VSCODE_DIR/settings.json" "$DOTFILES_DIR/vscode/settings.json"; then
    changes_made=true
fi
if backup_if_changed "$VSCODE_DIR/keybindings.json" "$DOTFILES_DIR/vscode/keybindings.json"; then
    changes_made=true
fi

# Update VSCode extensions list
if command -v code >/dev/null; then
    temp_extensions=$(mktemp)
    code --list-extensions > "$temp_extensions"
    if [ ! -f "$DOTFILES_DIR/vscode/extensions.txt" ] || ! cmp -s "$temp_extensions" "$DOTFILES_DIR/vscode/extensions.txt"; then
        echo "Updating VSCode extensions list..."
        mv "$temp_extensions" "$DOTFILES_DIR/vscode/extensions.txt"
        changes_made=true
    else
        rm "$temp_extensions"
    fi
fi

# If changes were made, commit and push them
if [ "$changes_made" = true ]; then
    echo "Changes detected, updating git repository..."
    cd "$DOTFILES_DIR"
    
    # Check if there are any changes to commit
    if ! git diff --quiet || ! git diff --staged --quiet; then
        # Get current timestamp for commit message
        timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        
        git add .
        git commit -m "Update dotfiles - $timestamp"
        
        # Check if remote exists and push
        if git remote get-url origin >/dev/null 2>&1; then
            echo "Pushing changes to remote repository..."
            git push
        else
            echo "No remote repository configured. Changes committed locally only."
        fi
        
        echo "Dotfiles updated successfully!"
    else
        echo "No changes to commit."
    fi
else
    echo "No changes detected in any configurations."
fi

# Verify all symbolic links are correct (if you're using symlinks)
verify_symlink() {
    local source=$1
    local target=$2
    if [ -L "$target" ]; then
        local current_link=$(readlink "$target")
        if [ "$current_link" != "$source" ]; then
            echo "Warning: Symlink for $(basename "$target") is incorrect."
            echo "Expected: $source"
            echo "Current: $current_link"
        fi
    elif [ -f "$target" ]; then
        echo "Warning: $(basename "$target") exists but is not a symlink."
    fi
}

# Add verification for common symlinks if you're using them
# verify_symlink "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
# verify_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
# verify_symlink "$DOTFILES_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"