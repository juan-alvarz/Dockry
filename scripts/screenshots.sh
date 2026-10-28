#!/usr/bin/env bash
# Runs build/Dockry.app next to a few other apps and saves screenshots to the given folder.
# Made for GitHub's throwaway macOS runners: it changes the system Dock's settings and
# quits apps, so don't run it on your own Mac.
set -euo pipefail
cd "$(dirname "$0")/.."
out=${1:-docs/screenshots}
mkdir -p "$out"
bundle_id=io.github.juan-alvarz.Dockry

# The Dock settings Dockry changes while it hides the system Dock.
dock_settings() {
  for key in autohide autohide-delay; do
    echo "$key=$(defaults read com.apple.dock "$key" 2>/dev/null || echo unset)"
  done
}
original_settings=$(dock_settings)

# Apps for the "running" part of the dock: two pinned in Work, two that aren't.
for app in Safari Notes Calculator TextEdit; do
  open -a "$app" || echo "couldn't open $app"
done
sleep 5

defaults write "$bundle_id" hideSystemDock -bool true
open build/Dockry.app
sleep 6
screencapture -x "$out/1-work-profile.png"

# ⌃⌥2 is Dockry's hot key for the second profile, Chill. key code 19 is the 2 key.
osascript -e 'tell application "System Events" to key code 19 using {control down, option down}' \
  || echo "couldn't send the hot key"
sleep 2
screencapture -x "$out/2-chill-profile.png"

# Open Dockry's menu bar menu.
osascript -e 'tell application "System Events" to tell process "Dockry" to click menu bar item 1 of last menu bar' \
  || echo "couldn't open the menu bar menu"
sleep 1
screencapture -x "$out/3-menu-bar.png"
osascript -e 'tell application "System Events" to key code 53' || true  # Esc closes the menu

# Quitting has to give the system Dock its original settings back.
pkill -TERM -x Dockry
sleep 3
restored_settings=$(dock_settings)
if [[ "$restored_settings" != "$original_settings" ]]; then
  echo "Dock settings after quitting: $restored_settings; expected: $original_settings" >&2
  exit 1
fi
echo "Screenshots saved to $out; the system Dock was restored."
