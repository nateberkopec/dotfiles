function check_github_actions_pinned
    set workflow_dir "$target_dir/.github/workflows"

    if not test -d "$workflow_dir"
        check_pass "GitHub Actions pinned"
        return
    end

    set unpinned_actions (grep -RHE "uses:[[:space:]]*['\"]?[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+[^[:space:]#]*@[^[:space:]#]+" "$workflow_dir" 2>/dev/null | grep -Ev "@[0-9a-f]{40}['\"]?([[:space:]#]|\$)")

    if test (count $unpinned_actions) -eq 0
        check_pass "GitHub Actions pinned"
    else
        check_fail "GitHub Actions pinned" "Pin workflow actions to full commit SHAs and keep the version as a comment, e.g. uses: actions/checkout@<sha> # v4. $unpinned_actions[1]"
    end
end
