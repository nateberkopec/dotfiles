### 13. hk Git Hooks

Git hooks are managed with [hk](https://hk.jdx.dev/). Configure them in `hk.pkl` at the project root.

The managed user config at `~/.config/hk/config.pkl` supplies `lint` and `test` steps to both `pre-commit` and `check`, calling the standard `mise run lint` and `mise run test` tasks. A project opts in by adding an `hk.pkl`; redefine those step names only when the project needs more granular checks or different commands.

Key rules:
- **Split hooks for parallelism.** hk runs steps in parallel, so separate independent checks rather than combining them into one script.
- **Pre-commit and check must include lint and test.** Keep both entry points equivalent except for checks that inherently depend on staged state.
- **Steps should invoke mise tasks.** Use `mise run <task>` as the check command.
- **Project definitions win.** User and project hooks merge additively; use the shared `lint` and `test` names when overriding defaults to avoid duplicate runs.
- **Use local overrides for personal exceptions.** Put `hk.local.pkl` next to `hk.pkl`, begin it with `amends "./hk.pkl"`, and exclude it with `.git/info/exclude` or `.gitignore`.

Minimal `hk.pkl` for projects using the standard tasks:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.57.0/hk@1.57.0#/Config.pkl"
```

A project with additional checks can redefine the shared names and reuse one mapping across hooks:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.57.0/hk@1.57.0#/Config.pkl"

local checks = new Mapping<String, Step> {
  ["lint"] {
    check = "mise run lint:standard"
  }
  ["complexity"] {
    check = "mise run lint:complexity"
  }
  ["test"] {
    check = "mise run test"
  }
}

hooks {
  ["pre-commit"] {
    steps = checks
  }
  ["check"] {
    steps = checks
  }
}
```

Ensure hk is in the mise `[tools]` section, then run `mise deps hk` when a custom dependency provider is configured, or:

```bash
mise run -- hk install
```
