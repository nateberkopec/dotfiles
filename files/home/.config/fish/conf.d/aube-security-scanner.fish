# Keep aube's Socket-compatible security scanner default-on in interactive shells.
# Temporarily disable with:
#   env AUBE_SECURITY_SCANNER= aube install
# or:
#   set -lx AUBE_SOCKET_SCANNER_DISABLE 1
function aube --wraps aube --description "Run aube with Socket's security scanner by default"
  if set -q AUBE_SOCKET_SCANNER_DISABLE; and test "$AUBE_SOCKET_SCANNER_DISABLE" != "0"
    command aube $argv
    return $status
  end

  if set -q AUBE_SECURITY_SCANNER
    command aube $argv
    return $status
  end

  set -l scanner "$HOME/.config/aube/socket-security-scanner.mjs"
  if test -f $scanner
    env AUBE_SECURITY_SCANNER=$scanner command aube $argv
  else
    command aube $argv
  end
end
