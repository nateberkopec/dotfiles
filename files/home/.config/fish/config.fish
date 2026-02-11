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
if status is-interactive
  set -x EDITOR "code --wait"
  set -x VISUAL "code --wait"
else
  set -x EDITOR true
  set -x VISUAL true
  set -x GIT_EDITOR true
end
set -x FZF_DEFAULT_COMMAND "fd --type f"
set -x AGENT_CMD "droid ."

# Activate mise early so cargo/gem/npm tools are available
if command -v mise >/dev/null 2>&1
  mise activate fish | source
  set -gx PATH ~/.cargo/bin $PATH
end

# Apply network status from starship check
function __mise_apply_network_status --on-event fish_prompt
  if test -f /tmp/mise_network_status
    if test (cat /tmp/mise_network_status) = "offline"
      set -gx MISE_OFFLINE 1
    else
      set -ge MISE_OFFLINE
    end
  end
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

# try-cli wrapper (avoid evaling Cancelled output)
set -g __try_rb (command ls -1t "$HOME/.local/share/mise/installs/gem-try-cli"/*/libexec/gems/try-cli-*/try.rb 2>/dev/null | head -n 1)
set -g __try_path "$HOME/src/tries"
if test -n "$__try_rb"
  function try
    set -l out (env SHELL=(status fish-path) command /usr/bin/env ruby "$__try_rb" exec --path "$__try_path" $argv 2>/dev/tty | string collect)
    set -l try_status $status
    set -l warning "# if you can read this, you didn't launch try from an alias. run try --help."

    if test $try_status -eq 0
      if string match -q "*$warning*" -- $out
        eval $out
      else if test -n "$out"
        echo $out
      end
    else if test -n "$out"
      echo $out
    end
  end
else if command -v try >/dev/null 2>&1
  function try
    command try $argv
  end
end

# starship prompt
if command -v starship >/dev/null 2>&1
  starship init fish | source
end

# OrbStack integration (macOS only)
if test -f ~/.orbstack/shell/init2.fish
  source ~/.orbstack/shell/init2.fish 2>/dev/null || :
end
