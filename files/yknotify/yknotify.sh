#!/bin/bash

# Notifies on YubiKey touch prompts. Managed by dotfiles; run as a
# LaunchAgent by `mise bootstrap` ([bootstrap.macos.launchd.agents.yknotify]).
# yubikey-icon.png alongside this script is from yubikey-manager-qt
# (BSD 2-Clause, Yubico AB).
# List of sounds: https://apple.stackexchange.com/a/479714
export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

MISE_BIN="$(command -v mise 2>/dev/null)"
YKNTFY_BIN=""
if [[ -n "$MISE_BIN" ]]; then
    YKNTFY_BIN="$($MISE_BIN which yknotify 2>/dev/null)"
fi
if [[ -z "$YKNTFY_BIN" ]]; then
    YKNTFY_BIN="$(command -v yknotify 2>/dev/null)"
fi
if [[ -z "$YKNTFY_BIN" || ! -x "$YKNTFY_BIN" ]]; then
    echo "yknotify binary not found" >&2
    exit 1
fi

TERM_NTFY_BIN="$(command -v terminal-notifier 2>/dev/null)"
ICON_PATH="$HOME/.local/share/yknotify/yubikey-icon.png"

# Tighten log predicate to reduce background CPU usage.
YKNTFY_PREDICATE='(processImagePath == "/kernel" AND senderImagePath ENDSWITH "IOHIDFamily" AND (eventMessage CONTAINS "IOHIDLibUserClient" OR eventMessage CONTAINS "AppleUserUSBHostHIDDevice" OR eventMessage ENDSWITH "startQueue" OR eventMessage ENDSWITH "stopQueue")) OR (processImagePath ENDSWITH "usbsmartcardreaderd" AND subsystem CONTAINS "CryptoTokenKit")'
YKNTFY_ARGS=(-predicate "$YKNTFY_PREDICATE")

LAST_NTFY=0
# Read one yknotify event per process so stale FIDO2 state does not loop forever.
while true; do
    TEMP_FIFO="$(mktemp "${TMPDIR:-/tmp}/yknotify.XXXXXX")"
    rm -f "$TEMP_FIFO"
    mkfifo "$TEMP_FIFO"

    "$YKNTFY_BIN" "${YKNTFY_ARGS[@]}" > "$TEMP_FIFO" &
    YKNTFY_PID=$!

    line=""
    if IFS= read -r line < "$TEMP_FIFO"; then
        kill "$YKNTFY_PID" 2>/dev/null || true
        wait "$YKNTFY_PID" 2>/dev/null || true
    else
        wait "$YKNTFY_PID" 2>/dev/null || true
    fi

    rm -f "$TEMP_FIFO"

    if [[ -z "$line" ]]; then
        sleep 1
        continue
    fi

    NOW="$(date +%s)"
    if [[ "$NOW" -le "$((LAST_NTFY + 2))" ]]; then
        continue
    fi
    LAST_NTFY="$NOW"

    message="$(echo "$line" | jq -r '.type')"
    if [[ -n "$TERM_NTFY_BIN" && -x "$TERM_NTFY_BIN" ]]; then
        "$TERM_NTFY_BIN" -title "YubiKey" -message "Touch to confirm $message" -sound Submarine -ignoreDnD -contentImage "$ICON_PATH"
    else
        osascript -e "display notification \"$message\" with title \"yknotify\""
    fi
done
