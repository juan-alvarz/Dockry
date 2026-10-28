#!/usr/bin/env bash
# Builds Dockry in release mode and wraps it in a runnable app bundle at build/Dockry.app.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/Dockry.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Dockry" "$app/Contents/MacOS/Dockry"
cp App/Info.plist "$app/Contents/Info.plist"
# Ad-hoc signature, enough to run locally and to be listed under Accessibility.
codesign --force --sign - "$app"
echo "Built $app"
