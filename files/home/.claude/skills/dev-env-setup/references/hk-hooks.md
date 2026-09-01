### 13. hk Git Hooks

Git hooks are managed with [hk](https://hk.jdx.dev/). Configure them in `hk.pkl` at the project root.

Key rules:
- **Split hooks for parallelism.** hk runs steps in parallel, so separate lint and test into distinct steps rather than combining them into one script.
- **Pre-commit must include lint and test.** These are the minimum gates before every commit.
- **Steps should invoke mise tasks.** Use `mise run <task>` as the check command.
- **Others' repos:** hk has no `.local.` config variant, so add `hk.pkl` to `.git/info/exclude` to keep it out of `git status`.

Template `hk.pkl`:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.39.0/hk@1.39.0#/Config.pkl"

hooks {
  ["pre-commit"] {
    steps {
      ["lint"] {
        check = "mise run lint:standard"
      }
      ["secrets"] {
        check = "mise run lint:secrets"
      }
      ["complexity"] {
        check = "mise run lint:complexity"
      }
      ["dead-code"] {
        check = "mise run lint:dead-code"
      }
      ["flog"] {
        check = "mise run lint:flog"
      }
      ["flay"] {
        check = "mise run lint:flay"
      }
      ["test"] {
        check = "mise run test"
      }
    }
  }
}
```

After creating `hk.pkl`, ensure hk is in the mise `[tools]` section and run:

```bash
mise run -- hk install
```

Or configure a custom `[deps.hk]` provider as shown above and run `mise deps hk`.
