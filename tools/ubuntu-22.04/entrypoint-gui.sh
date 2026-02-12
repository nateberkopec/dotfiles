#!/usr/bin/env bash

set -euo pipefail

DISPLAY="${DISPLAY:-:1}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
DOTF_LOG="${DOTF_LOG:-/tmp/dotf-run.stdout.log}"

setup_xfce_autostart() {
    mkdir -p "$HOME/.vnc" "$HOME/.config/autostart"
    : > "$DOTF_LOG"

    cat > "$HOME/.vnc/xstartup" <<'EOF'
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
    chmod +x "$HOME/.vnc/xstartup"

    cat > "$HOME/.config/autostart/dotf-log-tail.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=dotf run log tail
Comment=Show dotf run logs
Exec=xterm -T dotf-run-log -geometry 140x40 -e bash -lc "tail -n +1 -F /tmp/dotf-run.stdout.log"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
}

start_vnc() {
    local display_number="${DISPLAY#:}"
    rm -f "/tmp/.X${display_number}-lock" "/tmp/.X11-unix/X${display_number}" || true
    vncserver -kill "$DISPLAY" >/dev/null 2>&1 || true

    vncserver "$DISPLAY" \
        -rfbport "$VNC_PORT" \
        -localhost no \
        -SecurityTypes None \
        --I-KNOW-THIS-IS-INSECURE \
        -geometry 1920x1080 \
        -depth 24
}

start_novnc() {
    /usr/share/novnc/utils/launch.sh \
        --listen "$NOVNC_PORT" \
        --vnc "127.0.0.1:${VNC_PORT}" >/tmp/novnc.log 2>&1 &
    NOVNC_PID=$!
}

start_dotf_run() {
    : > "$DOTF_LOG"
    (
        cd /home/runner/dotfiles
        DEBUG=true ./bin/dotf run 2>&1 | tee "$DOTF_LOG"
    ) &
    DOTF_PID=$!
}

cleanup() {
    if [[ -n "${DOTF_PID:-}" ]]; then
        kill "$DOTF_PID" >/dev/null 2>&1 || true
    fi

    if [[ -n "${NOVNC_PID:-}" ]]; then
        kill "$NOVNC_PID" >/dev/null 2>&1 || true
    fi

    vncserver -kill "$DISPLAY" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

setup_xfce_autostart
start_vnc
start_novnc
start_dotf_run

wait "$NOVNC_PID"
