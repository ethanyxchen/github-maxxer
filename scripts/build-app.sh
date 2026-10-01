#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="$PWD/build/Hammertime.app"
require_app_stopped() {
  while read -r app_pid; do
    if [[ "$(ps -p "$app_pid" -o comm=)" == "$destination/Contents/MacOS/Hammertime" ]]; then
      printf 'Quit Hammertime before replacing its signed app bundle.\n' >&2
      exit 1
    fi
  done < <(pgrep -x Hammertime || true)
}
require_app_stopped
swift build -c release
binary_directory="$(swift build -c release --show-bin-path)"
mkdir -p "$PWD/build"
staging_directory="$(mktemp -d "$PWD/build/.hammertime.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
app_bundle="$staging_directory/Hammertime.app"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_directory/Hammertime" "$app_bundle/Contents/MacOS/Hammertime"
cp Resources/Info.plist "$app_bundle/Contents/Info.plist"
if [[ -n "${GITHUB_OAUTH_CLIENT_ID:-}" ]]; then
  plutil -replace GitHubOAuthClientID -string "$GITHUB_OAUTH_CLIENT_ID" "$app_bundle/Contents/Info.plist"
fi
cp Resources/AppIcon.icns "$app_bundle/Contents/Resources/AppIcon.icns"
plutil -lint "$app_bundle/Contents/Info.plist"
codesign --force --sign "${CODESIGN_IDENTITY:-Hammertime Development}" "$app_bundle"
codesign --verify --deep --strict "$app_bundle"
require_app_stopped
rm -rf "$destination"
mv "$app_bundle" "$destination"
printf 'Built %s\n' "$destination"
