#!/bin/sh
set -eu
checks=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ruby_bin=$(cat "$checks/ruby-bin")
bundle=$(cat "$checks/bundle-path")
export LD_LIBRARY_PATH="$checks/runtime-lib" BUNDLE_GEMFILE="$checks/Gemfile" BUNDLE_PATH="$bundle" BUNDLE_IGNORE_CONFIG=1
unset LD_PRELOAD RUBYOPT RUBYLIB BUNDLE_WITH BUNDLE_WITHOUT
exec "$ruby_bin/ruby" "$ruby_bin/bundle" exec "$ruby_bin/ruby" "$@"
