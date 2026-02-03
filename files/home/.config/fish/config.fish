if status is-interactive
  # macOS Homebrew setup
  if test -f /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
  end
end
fish_add_path ~/go/bin
# macOS-specific libpq
if test -d /opt/homebrew/opt/libpq/bin
  fish_add_path /opt/homebrew/opt/libpq/bin
end
fish_add_path ~/bin
fish_add_path ~/.local/bin

ulimit -S -n 4000

set -g fish_greeting

function fish_greeting
end

set -x LANG en_US.UTF-8
set -x LC_ALL en_US.UTF-8
set -x MAKEFLAGS -j(nproc)
set -x EDITOR "code --wait"
set -x FZF_DEFAULT_COMMAND "fd --type f"
set -x AGENT_CMD "droid ."

# Activate mise early so cargo/gem/npm tools are available
if command -v mise >/dev/null 2>&1
  mise activate fish | source
  set -gx PATH ~/.cargo/bin $PATH
end

zoxide init fish | source
complete -c z -f -k -a "(zoxide query -l)"
alias cd z
abbr be "bundle exec"
abbr cc "claude --allow-dangerously-skip-permissions"
alias oc droid
alias cat bat
alias ls eza
alias ll "eza -la"
alias tree "eza --tree"
fzf --fish | source
if command -v broot >/dev/null 2>&1
  broot --print-shell-function fish | source
end

function mosh
  command mosh --predict=experimental $argv
end

if test -f ~/.config/fish/private.fish
  source ~/.config/fish/private.fish
end

# macOS-specific mosh alias
if test -f /opt/homebrew/bin/mosh-server
  alias mosh-mbp "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local"
end

# try-cli init (requires mise-installed Ruby and gem)
if command -v try >/dev/null 2>&1
eval (env SHELL=(status fish-path) command try init ~/src/tries | string collect)
end

# starship prompt
if command -v starship >/dev/null 2>&1
  starship init fish | source
end

# OrbStack integration (macOS only)
if test -f ~/.orbstack/shell/init2.fish
  source ~/.orbstack/shell/init2.fish 2>/dev/null || :
end
