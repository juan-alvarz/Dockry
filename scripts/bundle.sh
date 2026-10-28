#!/usr/bin/env bash
# Builds Dockry in release mode and wraps it in a runnable app bundle at build/Dockry.app.
# Usage: scripts/bundle.sh [version]
# Given a version (as the release workflow does), it builds for both Apple silicon and Intel
# and stamps that version into the bundle.
set -euo pipefail
cd "$(dirname "$0")/.."
version=${1:-}

build_args=(-c release)
if [[ -n "$version" ]]; then
  build_args+=(--arch arm64 --arch x86_64)
fi
swift build "${build_args[@]}"
app=build/Dockry.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build "${build_args[@]}" --show-bin-path)/Dockry" "$app/Contents/MacOS/Dockry"
cp App/Info.plist "$app/Contents/Info.plist"
if [[ -n "$version" ]]; then
  plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
fi
# Ad-hoc signature, enough to run locally and to be listed under Accessibility.
codesign --force --sign - "$app"
echo "Built $app"
