#!/bin/sh
# Command Line Tools ship the Swift Testing macro plugin in a folder SwiftPM doesn't search, so point at it.
set -eu
cd "$(dirname "$0")/.."

plugins=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [ -d "$plugins" ] && ! xcode-select -p | grep -q Xcode.app; then
    exec swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
fi
exec swift test "$@"
