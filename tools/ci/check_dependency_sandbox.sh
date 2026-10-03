#!/usr/bin/env bash
set -euo pipefail

# Keep package downloads inside AWF, not in the host-side setup action.
command -v uv
export UV_CACHE_DIR="$(mktemp -d)"
uv run --no-project --with pyyaml==6.0.3 python -c 'import yaml; print("PyYAML available inside AWF:", yaml.__version__)'
