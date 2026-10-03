---
on:
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:

name: Dependency sandbox check
permissions:
  contents: read

imports:
  - shared/dependency-sandbox-engine.md
  - shared/dependency-sandbox.md

engine:
  id: dependency-sandbox-check

timeout-minutes: 10

safe-outputs:
  noop: false
---

Run the deterministic dependency sandbox check. No model requests or repository writes.
