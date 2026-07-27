### 4. Shell Aliases and Dependency Preparation

Use these mise features when setting up or auditing Ruby projects:

- **Prefer `[shell_alias]` to `hooks.enter` for project aliases.** Shell aliases work across bash, zsh, and fish and deactivate automatically when leaving the directory:

  ```toml
  [shell_alias]
  dfr = "./bin/dotf run"
  ```

  Reserve `hooks.enter` for setup that truly needs shell code.
- **Prefer mise dependency providers to manual setup tasks.** Current mise exposes this as `[deps]` / `mise deps` (older docs and articles may call the feature `[prepare]`). For Ruby repos, set Bundler to install dependencies into `vendor/bundle` and use the built-in Bundler provider so `bundle install` runs only when `Gemfile` or `Gemfile.lock` changes:

  ```toml
  [env]
  BUNDLE_PATH = "vendor/bundle"

  [deps.bundler]
  auto = true
  ```

  Add `vendor/bundle/` to the repo's ignore rules. Do not store private gem source credentials in Bundler config; keep them in 1Password/fnox and use the dotfiles `bundle-private` helper when private gem credentials are needed.

  Keep `hk install` as a one-shot command, or model it as a custom deps provider:

  ```toml
  [deps.hk]
  sources = ["hk.pkl"]
  outputs = [".git/hooks/pre-commit"]
  run = "hk install"
  ```

### 5. Serve URL Logging

If the project has a server, prefer a `serve` mise task. The `serve` task must log the server URL within the last 10 lines of output, for example `http://localhost:4000` or `https://localhost:4000`. This makes it easy for agents and humans to discover the running app URL.

If server startup needs setup logic, put it in a script such as `bin/serve` and keep the URL log near the end of the script output:

```fish
#!/usr/bin/env fish
bundle exec puma -p 4000 &
echo "http://localhost:4000"
wait
```

The checker runs `mise run serve` briefly and fails if the last 10 output lines do not include an HTTP or HTTPS URL.

### 6. Test Runtime

The checker runs `mise run test`, measures elapsed time, and warns when it takes longer than 10 seconds. Tests should still run before commit through the normal hk `test` step.

Acceptable remediations for a slow test task are:

- run tests only for changed files;
- add or use a `test:fast` task that still covers 100% of the app's unit-level coverage;
- keep the warning if neither approach can get the task under 10 seconds.

### 7. Large File Check

Pre-commit must include a large-file check so commits do not casually add too many lines to one file.

Add a dedicated mise task named `lint:large-files` that checks staged files:

```toml
[tasks."lint:large-files"]
description = "Check staged files for large files"
sources = [".git/index"]
run = '''git diff --cached --numstat --diff-filter=ACMR | awk -F '\t' '$1 ~ /^[0-9]+$/ && $1 > 100 { print "You are adding more than 100 lines to a file: " $3 " (+" $1 "). This is rarely necessary; consider simplifying the code. Is this the most YAGNI solution? Commit with --no-verify if needed."; bad=1 } END { exit bad }' '''
```

Keep this check self-contained in the mise task. It fails when a commit stages more than 100 added lines in any added, copied, modified, or renamed file. Existing files over 100 lines are fine unless the current staged change adds more than 100 lines to that file. There is no project script or override environment variable; use the normal `--no-verify` escape hatch if needed.
