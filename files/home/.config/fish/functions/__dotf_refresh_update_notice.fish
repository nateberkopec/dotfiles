function __dotf_refresh_update_notice
    set -l repo "$HOME/.dotfiles"
    set -q DOTFILES_DIR; and set repo "$DOTFILES_DIR"

    set -l state_home "$HOME/.local/state"
    set -q XDG_STATE_HOME; and set state_home "$XDG_STATE_HOME"

    set -l state_dir "$state_home/dotfiles"
    set -l checked_at "$state_dir/checked-at"
    set -l now (date +%s)

    if test -f "$checked_at"; and read -l last_check <"$checked_at"; and string match --quiet --regex '^\d+$' "$last_check"; and test (math "$now - $last_check") -lt 300
        return
    end

    command mkdir -p "$state_dir"
    command mkdir "$state_dir/check.lock" 2>/dev/null; or return

    printf '%s\n' "$now" >"$checked_at.tmp.$fish_pid"
    command mv "$checked_at.tmp.$fish_pid" "$checked_at"

    set -l fetch_ref refs/dotfiles/update-notice/main
    if env GIT_TERMINAL_PROMPT=0 \
            GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=3 -o ServerAliveInterval=3 -o ServerAliveCountMax=1' \
            git -C "$repo" fetch --quiet --no-tags origin "+refs/heads/main:$fetch_ref"; and test -f "$state_dir/last-run-sha"; and read -l applied_sha <"$state_dir/last-run-sha"
        set -l remote_sha (command git -C "$repo" rev-parse "$fetch_ref" 2>/dev/null)
        if test "$remote_sha" = "$applied_sha"; or command git -C "$repo" merge-base --is-ancestor "$remote_sha" "$applied_sha" 2>/dev/null
            command rm -f "$state_dir/needs-run"
        else
            printf 'dotf run\n' >"$state_dir/needs-run.tmp.$fish_pid"
            command mv "$state_dir/needs-run.tmp.$fish_pid" "$state_dir/needs-run"
        end
    end

    command rmdir "$state_dir/check.lock"
end
