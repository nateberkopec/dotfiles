if status is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end
fish_add_path /opt/homebrew/opt/libpq/bin
fish_add_path ~/bin

set -g fish_greeting

set -x LANG en_US.UTF-8
set -x LC_ALL en_US.UTF-8
set -x MAKEFLAGS -j(nproc)

zoxide init fish | source
complete -c z -f -k -a "(zoxide query -l)"
alias cd z
alias be="bundle exec"
alias cat bat
function mosh
  command mosh --predict=experimental $argv
end

if test -f ~/.config/fish/private.fish
  source ~/.config/fish/private.fish
end

alias mosh-mbp "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local"
alias mosh-mbp-tmux "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local -- /opt/homebrew/bin/tmux new-session -A -s main"

mise activate fish | source
direnv hook fish | source

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
