if status is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end
fish_add_path ~/go/bin
fish_add_path /opt/homebrew/opt/libpq/bin
fish_add_path ~/bin
fish_add_path ~/.local/bin

set -g fish_greeting

function fish_greeting
end

set -x LANG en_US.UTF-8
set -x LC_ALL en_US.UTF-8
set -x MAKEFLAGS -j(nproc)
set -x EDITOR "code --wait"
set -x FZF_DEFAULT_COMMAND "fd --type f"
set -x AGENT_CMD "droid ."

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
broot --print-shell-function fish | source

function mosh
  command mosh --predict=experimental $argv
end

if test -f ~/.config/fish/private.fish
  source ~/.config/fish/private.fish
end

alias mosh-mbp "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local"

eval (env SHELL=(status fish-path) ~/Documents/Code.nosync/upstream/try/try.rb init | string collect)

mise activate fish | source
set -gx PATH ~/.cargo/bin $PATH
starship init fish | source

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
