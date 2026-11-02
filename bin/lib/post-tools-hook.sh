#!/bin/bash

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0

label="gui/$(id -u)/dev.mise.activity-recall"
launchctl print "$label" >/dev/null 2>&1 || exit 0
launchctl kickstart "$label"
