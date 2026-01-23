#!/usr/bin/env -S jq -c -f

def RM_RF_PATTERN: "\\brm\\s+-[a-z]*r[a-z]*f[a-z]*\\s+|\\brm\\s+-[a-z]*f[a-z]*r[a-z]*\\s+";

def command: (.tool_input.command // "");

if .tool_name == "Bash" and (command | test(RM_RF_PATTERN; "i"))
then {updatedInput: {command: (command | gsub(RM_RF_PATTERN; "trash "; "i"))}}
else empty end
