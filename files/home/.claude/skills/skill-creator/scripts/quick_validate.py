#!/usr/bin/env python3
"""Validate a skill directory and its SKILL.md frontmatter."""

import re
import sys
from pathlib import Path

NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):(?:\s*(.*))?$")


def frontmatter(content):
    lines = content.splitlines()
    if not lines or lines[0] != "---":
        return None, "No YAML frontmatter found"
    try:
        end = lines.index("---", 1)
    except ValueError:
        return None, "Invalid frontmatter format: missing closing delimiter"

    fields = {}
    index = 1
    while index < end:
        match = KEY.match(lines[index])
        if not match:
            index += 1
            continue
        key, value = match.groups()
        values = fields.setdefault(key, [])
        if value in ("|", ">"):
            continuation = []
            index += 1
            while index < end and (lines[index].startswith(" ") or not lines[index]):
                continuation.append(lines[index].strip())
                index += 1
            values.append("\n".join(continuation).strip())
            continue
        scalar = (value or "").strip()
        if scalar.startswith(("'", '"')) and scalar.endswith(scalar[0]):
            scalar = scalar[1:-1]
        elif not scalar or scalar.startswith(("#", "[", "{", "&", "*", "!")) or scalar in ("null", "Null", "NULL", "~"):
            scalar = ""
        values.append(scalar)
        index += 1
    return fields, None


def validate_skill(skill_path):
    skill_path = Path(skill_path)
    skill_md = skill_path / "SKILL.md"
    if not skill_md.is_file():
        return False, "SKILL.md not found"

    fields, error = frontmatter(skill_md.read_text())
    if error:
        return False, error
    for required in ("name", "description"):
        values = fields.get(required, [])
        if len(values) != 1 or not values[0]:
            return False, f"Frontmatter requires exactly one nonempty '{required}'"

    name = fields["name"][0]
    if len(name) > 40 or not NAME.fullmatch(name):
        return False, f"Name '{name}' must be 1–40 lowercase alphanumeric characters with single hyphens"
    if name != skill_path.name:
        return False, f"Name '{name}' must match directory name '{skill_path.name}'"
    if "<" in fields["description"][0] or ">" in fields["description"][0]:
        return False, "Description cannot contain angle brackets (< or >)"

    return True, "Skill is valid!"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_validate.py <skill_directory>")
        sys.exit(1)
    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
