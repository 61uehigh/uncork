#!/bin/sh
# Builds build/Uncork.app from the Swift package.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
bin="$(swift build -c release --show-bin-path)/Uncork"

app=build/Uncork.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Uncork"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
# Ad-hoc signature so the app runs locally. Releases need a Developer ID signature and notarization.
codesign --force --sign - "$app"

echo "$app"
