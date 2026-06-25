# Route supported package managers through Socket Firewall Free when sfw is installed.
# npm/yarn/pnpm are intentionally not wrapped here so aube's shell shims can
# route them through aube. Aube, mise, Homebrew, and APT are not supported
# package-manager frontends for the free firewall.
function __socket_firewall_enabled
  if set -q SOCKET_FIREWALL_DISABLE; and test "$SOCKET_FIREWALL_DISABLE" != "0"
    return 1
  end

  command -q sfw
end

function __socket_firewall_run
  set -l tool $argv[1]
  set -e argv[1]

  if __socket_firewall_enabled
    command sfw $tool $argv
  else
    command $tool $argv
  end
end

function pip --wraps pip --description "Run pip through Socket Firewall when available"
  __socket_firewall_run pip $argv
end

function pip3 --wraps pip3 --description "Run pip3 through Socket Firewall when available"
  __socket_firewall_run pip3 $argv
end

function uv --wraps uv --description "Run uv through Socket Firewall when available"
  __socket_firewall_run uv $argv
end

function cargo --wraps cargo --description "Run cargo through Socket Firewall when available"
  __socket_firewall_run cargo $argv
end
