# Prefer mise as the tool owner

We prefer `mise` over repo-specific scripts, Homebrew, APT, or ad hoc installers whenever it can reasonably own a tool, task, dependency hook, runtime, CLI, or system package. `mise system install` is preferred when mise can express a system package; direct OS package managers remain for bootstrap, GUI apps, OS integration, services, fonts, drivers, and gaps in mise support, while ad hoc installers require an exceptional reason because they are harder to audit, upgrade, and make cross-platform.
