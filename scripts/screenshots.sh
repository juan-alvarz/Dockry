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

# Accounts for the Fast User Switching widget (this runner only has its own).
for user in "alex:Alex Rivera" "sam:Sam Chen"; do
  sudo sysadminctl -addUser "${user%%:*}" -fullName "${user#*:}" -password "dockry-ci" 2>/dev/null \
    || echo "couldn't create the account ${user%%:*}"
done

# Apps for the "running" part of the dock: two pinned in Work, two that aren't.
for app in Safari Notes Calculator TextEdit; do
  open -a "$app" || echo "couldn't open $app"
done
sleep 5

defaults write "$bundle_id" hideSystemDock -bool true
open build/Dockry.app
sleep 6
screencapture -x "$out/1-work-profile.png"

# Copy a few things, then ⌃⌥V (key code 9 is V) opens the clipboard history above the dock.
for text in "https://github.com/juan-alvarz/Dockry" "git checkout -b dev-clipboard origin/dev" \
  "Meeting notes: ship the clipboard widget, review the PRs in the morning"; do
  printf '%s' "$text" | pbcopy
  sleep 1
done
osascript -e 'tell application "System Events" to key code 9 using {control down, option down}' \
  || echo "couldn't open the clipboard history"
sleep 1
screencapture -x "$out/5-clipboard.png"
osascript -e 'tell application "System Events" to key code 9 using {control down, option down}' || true
sleep 1

# ⌃⌥2 is Dockry's hot key for the second profile, Chill. key code 19 is the 2 key.
osascript -e 'tell application "System Events" to key code 19 using {control down, option down}' \
  || echo "couldn't send the hot key"
sleep 2
swift scripts/fake-spotify-track.swift || echo "couldn't post the Spotify notification"
sleep 2
screencapture -x "$out/2-chill-profile.png"

# Hold ⌃⌥ and tap Space (key code 49): the switcher opens with the next profile, Work, selected.
osascript -e 'tell application "System Events"
  key down control
  key down option
  key code 49
end tell' || echo "couldn't open the profile switcher"
sleep 1
screencapture -x "$out/3-profile-switcher.png"
# Letting go of ⌃⌥ switches to the selected profile; the menu screenshot should show Work.
osascript -e 'tell application "System Events"
  key up option
  key up control
end tell' || true
sleep 2

# Open Dockry's menu bar menu.
osascript -e 'tell application "System Events" to tell process "Dockry" to click menu bar item 1 of last menu bar' \
  || echo "couldn't open the menu bar menu"
sleep 1
screencapture -x "$out/4-menu-bar.png"
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
