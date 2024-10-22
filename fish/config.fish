if status is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end
fish_add_path /opt/homebrew/opt/libpq/bin
fish_add_path ~/bin

set -g fish_greeting

zoxide init fish | source
complete -c z -f -k -a "(zoxide query -l)"
alias cd z
alias be="bundle exec"

source /opt/homebrew/opt/asdf/libexec/asdf.fish
direnv hook fish | source

functions --copy fish_prompt fish_prompt_original

function fish_prompt
  gh_client_notes
  echo -n $gh_status_indicator
  fish_prompt_original
end
