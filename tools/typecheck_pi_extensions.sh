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
  echo "Pi 0.85.1 is required to type-check Pi extensions" >&2
  exit 1
fi

ai_root=$(find "$dependency_root" "$agent_root/node_modules" \
  -path '*/@earendil-works/pi-ai/dist/index.d.ts' -print -quit 2>/dev/null || true)
ai_root=${ai_root%/dist/index.d.ts}
if [[ -z "$ai_root" ]]; then
  echo "Pi's @earendil-works/pi-ai dependency is missing" >&2
  exit 1
fi

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
      "@earendil-works/pi-ai/providers/all": ["$ai_root/dist/providers/all.d.ts"],
      "@earendil-works/pi-coding-agent": ["$agent_root/dist/index.d.ts"]
    },
    "skipLibCheck": true,
    "strict": true,
    "target": "ES2023"
  },
  "files": [
    "$PWD/files/home/.pi/agent/extensions/meridian.ts",
    "$PWD/files/home/.pi/agent/extensions/openrouter_us/index.ts",
    "$PWD/files/home/.pi/agent/extensions/toksec/index.ts",
    "$PWD/files/home/.pi/agent/extensions/vercel_us.ts"
  ]
}
JSON

tsc --project "$config"
