#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
binary_directory="$(swift build -c release --show-bin-path)"
app_bundle="$PWD/build/Hammertime.app"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_directory/Hammertime" "$app_bundle/Contents/MacOS/Hammertime"
cp Resources/Info.plist "$app_bundle/Contents/Info.plist"
if [[ -n "${GITHUB_OAUTH_CLIENT_ID:-}" ]]; then
  plutil -replace GitHubOAuthClientID -string "$GITHUB_OAUTH_CLIENT_ID" "$app_bundle/Contents/Info.plist"
fi
cp Resources/AppIcon.icns "$app_bundle/Contents/Resources/AppIcon.icns"
plutil -lint "$app_bundle/Contents/Info.plist"
codesign --force --sign "${CODESIGN_IDENTITY:--}" "$app_bundle"
printf 'Built %s\n' "$app_bundle"
