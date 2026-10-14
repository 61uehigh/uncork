#!/bin/sh
# Regenerates Resources/AppIcon.icns from scripts/icon/AppIcon.swift.
set -eu
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swiftc -parse-as-library -o "$work/render" Sources/Uncork/UncorkMark.swift scripts/icon/AppIcon.swift
"$work/render" "$work/icon_1024.png"

iconset="$work/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$work/icon_1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$work/icon_1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns -o Resources/AppIcon.icns "$iconset"

echo Resources/AppIcon.icns
