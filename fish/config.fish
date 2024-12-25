if status is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end
fish_add_path /opt/homebrew/opt/libpq/bin
fish_add_path ~/bin

set -g fish_greeting

set -x LANG en_US.UTF-8
set -x LC_ALL en_US.UTF-8
set -x MAKEFLAGS -j(nproc)
set -x RUBY_CONFIGURE_OPTS '--enable-yjit'

zoxide init fish | source
complete -c z -f -k -a "(zoxide query -l)"
alias cd z
alias be="bundle exec"
function mosh
  command mosh --predict=experimental $argv
end

alias mosh-mbp "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local"
alias mosh-mbp-tmux "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local -- /opt/homebrew/bin/tmux new-session -A -s main"

direnv hook fish | source

functions --copy fish_prompt fish_prompt_original

function fish_prompt
  gh_client_notes
  echo -n $gh_status_indicator
  fish_prompt_original
end
