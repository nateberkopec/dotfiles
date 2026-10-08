function __dotf_refresh_update_notice
    set -l state_home "$HOME/.local/state"
    set -q XDG_STATE_HOME; and set state_home "$XDG_STATE_HOME"
    set -l state_dir "$state_home/dotfiles"
    command mkdir -p "$state_dir"

    if test "$argv[1]" != --locked
        set -l fish_bin (status fish-path)
        set -l source_file (functions --details __dotf_refresh_update_notice)
        switch (uname -s)
            case Darwin
                command lockf -k -s -t 0 "$state_dir/check.flock" "$fish_bin" --no-config --command 'source $argv[1]; __dotf_refresh_update_notice --locked' "$source_file"
            case Linux
                command flock -n "$state_dir/check.flock" "$fish_bin" --no-config --command 'source $argv[1]; __dotf_refresh_update_notice --locked' "$source_file"
        end
        return 0
    end

    set -l repo "$HOME/.dotfiles"
    set -q DOTFILES_DIR; and set repo "$DOTFILES_DIR"

    set -l checked_at "$state_dir/checked-at"
    set -l now (date +%s)

    if test -f "$checked_at"; and read -l last_check <"$checked_at"; and string match --quiet --regex '^\d+$' "$last_check"; and test (math "$now - $last_check") -lt 300
        return
    end

    printf '%s\n' "$now" >"$checked_at.tmp.$fish_pid"
    command mv "$checked_at.tmp.$fish_pid" "$checked_at"

    # Public GitHub reads need no SSH key or credential helper.
    set -l fetch_url (command git -C "$repo" remote get-url origin); or return
    set fetch_url (string replace --regex '^(git@github\.com:|ssh://git@github\.com/)' 'https://github.com/' -- "$fetch_url")
    set -l fetch_ref refs/dotfiles/update-notice/main
    if env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true GIT_SSH_COMMAND=false \
            git -C "$repo" -c credential.helper= fetch --quiet --no-tags "$fetch_url" "+refs/heads/main:$fetch_ref"; and test -f "$state_dir/last-run-sha"; and read -l applied_sha <"$state_dir/last-run-sha"
        set -l remote_sha (command git -C "$repo" rev-parse "$fetch_ref" 2>/dev/null)
        if test "$remote_sha" = "$applied_sha"; or command git -C "$repo" merge-base --is-ancestor "$remote_sha" "$applied_sha" 2>/dev/null
            command rm -f "$state_dir/needs-run"
        else
            printf 'dotf run\n' >"$state_dir/needs-run.tmp.$fish_pid"
            command mv "$state_dir/needs-run.tmp.$fish_pid" "$state_dir/needs-run"
        end
    end

end
