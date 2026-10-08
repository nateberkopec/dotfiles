#!/usr/bin/env bash
set -euo pipefail

agent_root=""
dependency_root=""
if command -v npm >/dev/null 2>&1; then
  global_root=$(npm root --global)
  candidate="$global_root/@earendil-works/pi-coding-agent"
  if [[ -f "$candidate/dist/index.d.ts" ]]; then
    agent_root="$candidate"
    dependency_root="$global_root"
  fi
fi
if [[ -z "$agent_root" ]] && command -v mise >/dev/null 2>&1; then
  install_root=$(mise where npm:@earendil-works/pi-coding-agent)
  agent_root=$(find "$install_root" -path '*/@earendil-works/pi-coding-agent/dist/index.d.ts' -print -quit)
  agent_root=${agent_root%/dist/index.d.ts}
  dependency_root="$install_root"
fi
if [[ -z "$agent_root" ]]; then
  echo "Pi is required to type-check Pi extensions" >&2
  exit 1
fi

ai_root=$(find "$dependency_root" "$agent_root/node_modules" \
  -path '*/@earendil-works/pi-ai/dist/index.d.ts' -print -quit 2>/dev/null || true)
ai_root=${ai_root%/dist/index.d.ts}
if [[ -z "$ai_root" ]]; then
  echo "Pi's @earendil-works/pi-ai dependency is missing" >&2
  exit 1
fi

tui_root=$(find "$dependency_root" "$agent_root/node_modules" \
  -path '*/@earendil-works/pi-tui/dist/index.d.ts' -print -quit 2>/dev/null || true)
tui_root=${tui_root%/dist/index.d.ts}
if [[ -z "$tui_root" ]]; then
  echo "Pi's @earendil-works/pi-tui dependency is missing" >&2
  exit 1
fi

typebox_types=$(node -e '
  const { createRequire } = require("node:module");
  const resolve = createRequire(process.argv[1] + "/package.json").resolve;
  console.log(resolve("typebox").replace(/\.mjs$/, ".d.mts"));
' "$agent_root")

config=$(mktemp)
trap 'rm -f "$config"' EXIT
cat >"$config" <<JSON
{
  "compilerOptions": {
    "allowImportingTsExtensions": true,
    "lib": ["ES2023", "DOM"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "noEmit": true,
    "paths": {
      "@earendil-works/pi-ai": ["$ai_root/dist/index.d.ts"],
      "@earendil-works/pi-ai/compat": ["$ai_root/dist/compat.d.ts"],
      "@earendil-works/pi-ai/providers/all": ["$ai_root/dist/providers/all.d.ts"],
      "@earendil-works/pi-coding-agent": ["$agent_root/dist/index.d.ts"],
      "@earendil-works/pi-tui": ["$tui_root/dist/index.d.ts"],
      "typebox": ["$typebox_types"]
    },
    "skipLibCheck": true,
    "strict": true,
    "target": "ES2023"
  },
  "files": [
    "$PWD/.pi/extensions/dotf_run/index.ts",
    "$PWD/files/home/.pi/agent/extensions/caffeinate.ts",
    "$PWD/files/home/.pi/agent/extensions/notify.ts",
    "$PWD/files/home/.pi/agent/extensions/window-fork.ts",
    "$PWD/files/home/.pi/agent/extensions/meridian.ts",
    "$PWD/files/home/.pi/agent/extensions/conversation_title.ts",
    "$PWD/files/home/.pi/agent/extensions/datasafe/index.ts",
    "$PWD/files/home/.pi/agent/extensions/toksec/index.ts",
    "$PWD/files/home/.pi/agent/extensions/executor-watch/index.ts",
    "$PWD/files/home/.pi/agent/extensions/herdr-status/index.ts",
    "$PWD/files/home/.pi/agent/extensions/you-should-know/index.ts",
    "$PWD/files/home/.pi/agent/extensions/btw/index.ts",
    "$PWD/test/support/you_should_know_provider.ts",
    "$PWD/test/support/you_should_know_transport.ts"
  ]
}
JSON

tsc --project "$config"
