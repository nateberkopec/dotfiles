function pi-fm --description "Run Pi against Apple's on-device Foundation Model with a minimal context"
  set -l health http://127.0.0.1:1976/health
  set -l server_pid

  if not curl -sf $health >/dev/null
    fm serve --port 1976 >/dev/null 2>&1 &
    set server_pid $last_pid
    for i in (seq 50)
      curl -sf $health >/dev/null; and break
      sleep 0.1
    end
  end

  PI_CODING_AGENT_DIR=$HOME/.pi/fm pi --offline -nt -ns -ne -np -nc -na $argv
  set -l pi_status $status

  if test -n "$server_pid"
    kill $server_pid
  end
  return $pi_status
end
