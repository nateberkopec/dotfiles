for name in (set --names | string match 'HERDR_*')
    set --erase $name
end

function stop --on-signal TERM --on-signal HUP
    kill $last_pid 2>/dev/null
    exit
end

while kill -0 $argv[2] 2>/dev/null
    sleep 300 &
    wait $last_pid
    kill -0 $argv[2] 2>/dev/null; or break
    command herdr --session $argv[1] plugin action invoke sync --plugin dotfiles.session-template >/dev/null &
    wait $last_pid
end
