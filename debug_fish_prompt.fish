#!/usr/bin/env fish

echo "=== Fish Prompt Debug Info ==="
echo ""

echo "Fish version:"
fish --version
echo ""

echo "Mise version:"
mise --version
echo ""

echo "Mise status:"
mise doctor
echo ""

echo "OMF installed themes:"
omf list
echo ""

echo "Current theme:"
cat ~/.config/omf/theme 2>/dev/null || echo "No theme file found"
echo ""

echo "Bobthefish installed:"
test -d ~/.local/share/omf/themes/bobthefish && echo "Yes" || echo "No"
echo ""

echo "Bobthefish theme variables:"
set -g | grep theme_
echo ""

echo "Mise environment variables:"
env | grep -i mise
echo ""

echo "PATH:"
echo $PATH
echo ""

echo "Functions containing 'fish_prompt':"
functions -n | grep prompt
echo ""

echo "Fish prompt function source:"
type fish_prompt
echo ""

echo "Mise current config:"
mise current
echo ""

echo "Testing mise in current directory:"
mise exec -- echo "mise exec works"
echo ""

echo "Fish config location:"
ls -la ~/.config/fish/config.fish
echo ""

echo "OMF config location:"
ls -la ~/.config/omf/
echo ""
