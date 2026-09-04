# Safety defaults for interactive and agent-launched Bash shells.

export MISE_SHELL=bash

if command -v mise >/dev/null 2>&1; then
  eval "$(mise hook-env -s bash)"
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
  eval "$(aube activate bash)"
  _path_force_prepend "$AUBE_SHIM_DIR"
fi
unset -f _path_force_prepend

_socket_firewall_enabled() {
  [[ -z "${SOCKET_FIREWALL_DISABLE:-}" || "$SOCKET_FIREWALL_DISABLE" == "0" ]] && command -v sfw >/dev/null 2>&1
}

_socket_firewall_run() {
  local tool="$1"
  shift

  if _socket_firewall_enabled; then
    SOCKET_FIREWALL_DISABLE=1 command sfw "$tool" "$@"
  else
    command "$tool" "$@"
  fi
}

pip() { _socket_firewall_run pip "$@"; }
pip3() { _socket_firewall_run pip3 "$@"; }
uv() { _socket_firewall_run uv "$@"; }
cargo() { _socket_firewall_run cargo "$@"; }
