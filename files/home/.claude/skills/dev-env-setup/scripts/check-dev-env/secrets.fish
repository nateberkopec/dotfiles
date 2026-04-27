function check_secrets
    if not command -q gitleaks
        check_warn "no plaintext secrets in working tree" "gitleaks is not installed. Add 'gitleaks = \"latest\"' to ~/.config/mise/config.toml (or the project mise config) so the audit can scan for hardcoded secrets."
        return
    end

    set baseline_args
    set baseline_file "$target_dir/.gitleaks-baseline.json"
    if test -f "$baseline_file"
        set baseline_args --baseline-path "$baseline_file"
    end

    set config_args
    if not test -f "$target_dir/.gitleaks.toml"
        set config_args --config "$script_dir/check-dev-env/gitleaks-default.toml"
    end

    set scan_output (builtin cd "$target_dir"; and gitleaks dir \
        --redact=75 \
        --no-banner \
        --no-color \
        --max-target-megabytes 5 \
        $config_args \
        $baseline_args \
        . 2>&1)
    set scan_status $status

    if test $scan_status -eq 0
        check_pass "no plaintext secrets in working tree"
        return
    end

    set finding_count (string match -rg 'leaks found:\s*(\d+)' -- (string join \n -- $scan_output))
    if test -z "$finding_count"
        set finding_count "?"
    end
    set summary "gitleaks reported $finding_count finding(s). Run 'gitleaks dir -v $target_dir' to see details."
    set remediation "Real secrets must live in fnox/1Password — see the env-to-fnox skill. For false positives, add the printed fingerprint to .gitleaksignore or annotate the line with a 'gitleaks:allow' comment. To accept all current findings as a baseline (e.g., when adopting on an existing repo), run: gitleaks dir --report-path .gitleaks-baseline.json $target_dir"
    check_fail "no plaintext secrets in working tree" "$summary $remediation"
end
