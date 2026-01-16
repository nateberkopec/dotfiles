#!/usr/bin/env python3
import json
import re
import sys

RM_RF_PATTERN = re.compile(
    r"\brm\s+-[a-z]*r[a-z]*f[a-z]*\s+|\brm\s+-[a-z]*f[a-z]*r[a-z]*\s+", re.IGNORECASE
)


def main() -> int:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"Error: Invalid JSON input: {exc}", file=sys.stderr)
        return 1

    if input_data.get("tool_name") != "Bash":
        return 0

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    if RM_RF_PATTERN.search(command):
        new_command = RM_RF_PATTERN.sub("trash ", command)
        print(json.dumps({"updatedInput": {"command": new_command}}))

    return 0


if __name__ == "__main__":
    sys.exit(main())
