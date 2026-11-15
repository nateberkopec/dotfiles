# Safety defaults for interactive and agent-launched Bash shells.

export MISE_SHELL=bash

for _brew_dir in /opt/homebrew/bin /opt/homebrew/sbin "$HOME/.homebrew/bin" "$HOME/.homebrew/sbin"; do
  if [[ -d "$_brew_dir" && ":$PATH:" != *":$_brew_dir:"* ]]; then
    export PATH="$PATH:$_brew_dir"
  fi
done
unset _brew_dir

# Bash-backed startup tools must not recursively reload this file.
if command -v mise >/dev/null 2>&1; then
  eval "$(BASH_ENV='' MISE_STATUS_MESSAGE_MISSING_TOOLS=never mise hook-env -s bash)"
fi

_path_force_prepend() {
  local dir="$1" entry remainder=""
  local IFS=:

  for entry in $PATH; do
    if [[ "$entry" != "$dir" ]]; then
      remainder="${remainder:+$remainder:}$entry"
    fi
  done

  export PATH="$dir${remainder:+:$remainder}"
}

if command -v aube >/dev/null 2>&1; then
  eval "$(BASH_ENV='' aube activate bash)"
  _path_force_prepend "$AUBE_SHIM_DIR"
fi
unset -f _path_force_prepend
