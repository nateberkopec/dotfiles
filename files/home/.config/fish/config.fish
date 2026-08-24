set -gx MISE_FISH_AUTO_ACTIVATE 0

fish_add_path ~/go/bin
fish_add_path ~/bin
fish_add_path ~/.local/bin

ulimit -S -n 4000

set -g fish_greeting

function fish_greeting
    set -l state_home "$HOME/.local/state"
    set -q XDG_STATE_HOME; and set state_home "$XDG_STATE_HOME"

    if test -e "$state_home/dotfiles/needs-run"
        set -l message 'Dotfiles changed on origin/main.'
        set -l update_command 'cd ~/.dotfiles && git switch main && git pull --ff-only && dotf run'
        if command -q gum
            printf '%s\n%s\n' "$message" "$update_command" | gum style --bold --foreground 214
        else
            printf '%s\n%s\n' "$message" "$update_command"
        end
    end

    command fish --no-config --command __dotf_refresh_update_notice >/dev/null 2>&1 &
    disown $last_pid 2>/dev/null
    return 0
end

set -x LANG en_US.UTF-8
set -x LC_ALL en_US.UTF-8
if status is-interactive
  set -x EDITOR "code --wait"
  set -x VISUAL "code --wait"
else
  set -x EDITOR true
  set -x VISUAL true
  set -x GIT_EDITOR true
end
set -x FZF_DEFAULT_COMMAND "fd --type f"
set -x AGENT_CMD "pi"
set -Ux HOMEBREW_AUTO_UPDATE_SECS 604800
set -Ux HOMEBREW_NO_REQUIRE_TAP_TRUST 1

# Suppress pi's startup update/package-update notices for normal agent sessions.
# Leave package-management subcommands online so `pi update` still works.
function pi
  if test (count $argv) -gt 0
    switch $argv[1]
      case install remove uninstall update list
        command pi $argv
      case '*'
        env PI_SKIP_VERSION_CHECK=1 PI_OFFLINE=1 command pi $argv
    end
  else
    env PI_SKIP_VERSION_CHECK=1 PI_OFFLINE=1 command pi
  end
end

# Activate mise early so cargo/gem/npm tools are available
if command -v mise >/dev/null 2>&1
  mise activate fish --no-hook-env | source
  mise hook-env -s fish | source
  if command -q aube
    aube activate fish | source
  end

  function __mise_refresh_on_cd --on-variable PWD
    mise hook-env -s fish | source
  end

  set -gx PATH ~/.cargo/bin $PATH
end

zoxide init fish | source
complete -c z -f -k -a "(zoxide query -l)"
alias cd z
abbr be "bundle exec"
abbr bp "bundle-private"
abbr bpi "bundle-private install"
abbr cc "claude --allow-dangerously-skip-permissions"
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

# Optional untracked local env vars. Only use this for read-only credentials
# with no side effects, such as free keys that do not bill. Leaks of these keys
# should be a minor risk.
if test -f ~/.config/fish/private.fish
  source ~/.config/fish/private.fish
end

if set -l try_bin (command -s try)
  env SHELL=(status fish-path) "$try_bin" init ~/src/tries | source
end

# starship prompt
if command -v starship >/dev/null 2>&1
  starship init fish | source
end

