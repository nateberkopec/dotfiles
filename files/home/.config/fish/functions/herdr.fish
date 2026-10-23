function herdr --wraps herdr --description 'Herdr with a saved-machine catalog per session'
    set -l session (__herdr_session_name $argv)
    set -l state_root $HOME/.local/state
    set -q XDG_STATE_HOME; and set state_root $XDG_STATE_HOME
    if __herdr_attaching $argv
        __herdr_ensure_server $session; or return $status
        XDG_STATE_HOME=$state_root/herdr-sessions/$session command node $HOME/.local/share/dotfiles/herdr-plugins/session-template/client.mjs $session $argv
    else
        XDG_STATE_HOME=$state_root/herdr-sessions/$session command herdr $argv
    end
end

function __herdr_session_name
    set -l index (contains -i -- --session $argv)
    if test -n "$index"; and set -q argv[(math $index + 1)]
        echo $argv[(math $index + 1)]
        return
    end
    for arg in $argv
        if string match -q -- '--session=*' $arg
            string replace -- '--session=' '' $arg
            return
        end
    end
    if test "$argv[1]" = session; and test "$argv[2]" = attach; and set -q argv[3]
        echo $argv[3]
        return
    end
    if set -q HERDR_SESSION
        echo $HERDR_SESSION
        return
    end
    set -l socket (string match -r -- '/sessions/([^/]+)/herdr\.sock$' "$HERDR_SOCKET_PATH")
    if set -q socket[2]
        echo $socket[2]
        return
    end
    echo default
end

function __herdr_attaching
    switch (count $argv)
        case 0
            return 0
        case 1
            string match -q -- '--session=*' $argv[1]
        case 2
            test "$argv[1]" = --session
        case 3
            test "$argv[1]" = session; and test "$argv[2]" = attach
        case '*'
            return 1
    end
end

function __herdr_ensure_server --argument-names session
    command herdr --session $session workspace list >/dev/null 2>&1; and return 0
    command herdr --session $session server </dev/null >/dev/null 2>&1 &
    disown
    for attempt in (seq 100)
        command herdr --session $session workspace list >/dev/null 2>&1; and return 0
        sleep 0.1
    end
    echo "herdr: the $session server did not start within 10 seconds" >&2
    return 1
end
