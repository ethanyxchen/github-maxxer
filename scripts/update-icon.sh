#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/AppIcon.iconset
swiftc -O scripts/make-icon.swift -o build/make-icon
build/make-icon Sources/GitHubMaxxer/Resources build/icon.png
for icon_size in 16 32 128 256 512; do
    sips -z "$icon_size" "$icon_size" build/icon.png --out "build/AppIcon.iconset/icon_${icon_size}x${icon_size}.png" >/dev/null
    retina_size=$((icon_size * 2))
    sips -z "$retina_size" "$retina_size" build/icon.png --out "build/AppIcon.iconset/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
