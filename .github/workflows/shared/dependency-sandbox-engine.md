---
engine:
  id: dependency-sandbox-check
  display-name: Dependency sandbox check
  description: Run deterministic validation without a model call
  experimental: true
  mcp: false
  behaviors:
    execution:
      command-name: bash
      args: [tools/ci/check_dependency_sandbox.sh]
      step-name: Validate dependency sandbox
---
