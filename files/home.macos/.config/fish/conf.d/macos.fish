if status is-interactive
  if test -d /opt/homebrew
    set -gx HOMEBREW_PREFIX /opt/homebrew
    set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
    set -gx HOMEBREW_REPOSITORY /opt/homebrew
    fish_add_path -g -m /opt/homebrew/bin /opt/homebrew/sbin

    if test -d /opt/homebrew/share/info
      contains /opt/homebrew/share/info $INFOPATH; or set -gx INFOPATH /opt/homebrew/share/info $INFOPATH
    end
  end
end

if test -d /opt/homebrew/opt/libpq/bin
  fish_add_path /opt/homebrew/opt/libpq/bin
end

set -x MAKEFLAGS -j(sysctl -n hw.ncpu)

if test -f /opt/homebrew/bin/mosh-server
  alias mosh-mbp "mosh --server='SHELL=/opt/homebrew/bin/fish /opt/homebrew/bin/mosh-server' nateberkopec@MBP-Server.local"
end

if test -f ~/.orbstack/shell/init2.fish
  source ~/.orbstack/shell/init2.fish 2>/dev/null || :
end
