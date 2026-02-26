# Shared Bash setup for interactive shells and login shells used by agents.

# macOS Homebrew setup
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

path_prepend() {
  local dir="$1"
  [[ -d "$dir" ]] || return

  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
}

path_prepend "$HOME/go/bin"
path_prepend "/opt/homebrew/opt/libpq/bin"
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

export PATH

ulimit -S -n 4000 >/dev/null 2>&1 || true

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
if command -v nproc >/dev/null 2>&1; then
  export MAKEFLAGS="-j$(nproc)"
elif command -v sysctl >/dev/null 2>&1; then
  export MAKEFLAGS="-j$(sysctl -n hw.ncpu)"
fi

if [[ $- == *i* ]]; then
  export EDITOR="code --wait"
  export VISUAL="code --wait"
else
  export EDITOR="true"
  export VISUAL="true"
  export GIT_EDITOR="true"
fi

export FZF_DEFAULT_COMMAND="fd --type f"
export AGENT_CMD="droid ."

# Activate mise early so cargo/gem/npm tools are available.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
  path_prepend "$HOME/.cargo/bin"
  export PATH
fi

_apply_mise_network_status() {
  if [[ -f /tmp/mise_network_status ]]; then
    if [[ "$(</tmp/mise_network_status)" == "offline" ]]; then
      export MISE_OFFLINE=1
    else
      unset MISE_OFFLINE
    fi
  fi
}

if [[ $- == *i* ]]; then
  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="_apply_mise_network_status; $PROMPT_COMMAND"
  else
    PROMPT_COMMAND="_apply_mise_network_status"
  fi
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

if [[ $- == *i* ]]; then
  alias be='bundle exec'
  alias cc='claude --allow-dangerously-skip-permissions'
  alias oc='droid'
  alias cat='bat'
  alias ls='eza'
  alias ll='eza -la'
  alias tree='eza --tree'

  if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi

  if command -v broot >/dev/null 2>&1; then
    eval "$(broot --print-shell-function bash)"
  fi
fi

mosh() {
  command mosh --predict=experimental "$@"
}

if [[ -f "$HOME/.config/bash/private.bash" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.config/bash/private.bash"
fi

if [[ -x /opt/homebrew/bin/mosh-server ]]; then
  alias mosh-mbp="mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local"
fi

# try-cli wrapper (avoid evaling Cancelled output)
__try_rb="$(command ls -1t "$HOME/.local/share/mise/installs/gem-try-cli"/*/libexec/gems/try-cli-*/try.rb 2>/dev/null | head -n 1)"
__try_path="$HOME/src/tries"

if [[ -n "$__try_rb" ]]; then
  try() {
    local out try_status
    local warning="# if you can read this, you didn't launch try from an alias. run try --help."

    out="$(env SHELL="$(command -v bash)" command /usr/bin/env ruby "$__try_rb" exec --path "$__try_path" "$@" 2>/dev/tty)"
    try_status=$?

    if [[ $try_status -eq 0 ]]; then
      if [[ "$out" == *"$warning"* ]]; then
        eval "$out"
      elif [[ -n "$out" ]]; then
        printf '%s\n' "$out"
      fi
    elif [[ -n "$out" ]]; then
      printf '%s\n' "$out"
    fi

    return $try_status
  }
elif command -v try >/dev/null 2>&1; then
  try() {
    command try "$@"
  }
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# OrbStack integration (macOS only)
if [[ -f "$HOME/.orbstack/shell/init2.bash" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.orbstack/shell/init2.bash" 2>/dev/null || :
elif [[ -f "$HOME/.orbstack/shell/init2.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.orbstack/shell/init2.sh" 2>/dev/null || :
fi
