#!/usr/bin/env python3
import json
import re
import sys

RM_RF_PATTERN = re.compile(
    r"(^|[;&|]\s*)\s*(?:sudo\s+)?(?:command\s+)?rm\s+-(?:rf|fr)\b"
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
        print("Refusing to run `rm -rf`. Use `trash` instead.", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
