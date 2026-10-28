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

# Dragging Safari two places to the right (2 × 54 points) has to save the new order.
swift scripts/drag-app.swift Safari 108 "$out/11-drag-to-reorder.png"
sleep 1
profiles="$HOME/Library/Application Support/Dockry/profiles.json"
order=$(python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(" ".join(next(p["pinnedApps"] for p in d["profiles"] if p["name"] == "Work")))' "$profiles")
if [[ "$order" != "com.apple.finder com.apple.mail com.apple.iCal com.apple.Safari com.apple.Notes com.apple.Terminal" ]]; then
  echo "Dragging Safari didn't reorder the dock; Work's pinned apps are: $order" >&2
  exit 1
fi
# ...without also clicking it, which would have brought Safari to the front.
frontmost=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')
if [[ "$frontmost" == "Safari" ]]; then
  echo "Letting go after dragging Safari also opened it" >&2
  exit 1
fi
# A plain click (a "drag" of 0 points) still has to open the app.
swift scripts/drag-app.swift Calculator 0
sleep 1
frontmost=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')
if [[ "$frontmost" != "Calculator" ]]; then
  echo "Clicking Calculator in the dock didn't bring it to the front; $frontmost is in front" >&2
  exit 1
fi

# Copy a few things, then ⌃⌥V (key code 9 is V) opens the clipboard history above the dock.
for text in "https://github.com/juan-alvarz/Dockry" "git checkout -b dev-clipboard origin/dev" \
  "Meeting notes: ship the clipboard widget, review the PRs in the morning"; do
  printf '%s' "$text" | pbcopy
  sleep 1
done
osascript -e 'tell application "System Events" to key code 9 using {control down, option down}' \
  || echo "couldn't open the clipboard history"
sleep 1
screencapture -x "$out/11-clipboard.png"
# Clicking an entry with a real mouse click has to copy it, on the first click.
swift scripts/click-text.swift "git checkout -b dev-clipboard origin/dev"
sleep 1
if [[ "$(pbpaste)" != "git checkout -b dev-clipboard origin/dev" ]]; then
  echo "Clicking a clipboard history entry didn't copy it; the clipboard has: $(pbpaste)" >&2
  exit 1
fi

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

# Quits Dockry and opens it again with the given launch arguments (see ScreenshotHook).
relaunch() {
  pkill -TERM -x Dockry || true
  sleep 3
  open build/Dockry.app --args "$@"
  sleep 6
}

# Magnification, with the pointer over the dock (-1 is the middle of the screen).
defaults write "$bundle_id" magnifies -bool true
defaults write "$bundle_id" magnifiedSize -float 96
relaunch -logPointer YES
swift scripts/move-mouse.swift -1 36 || echo "couldn't move the pointer"
sleep 1
screencapture -x "$out/5-magnification.png"
log show --last 20s --style compact --predicate 'process == "Dockry"' 2>/dev/null | grep "Dockry pointer" || echo "Dockry logged no pointer changes"

# A smaller dock on the left edge, with an icon's name showing.
defaults write "$bundle_id" magnifies -bool false
defaults write "$bundle_id" position -string left
defaults write "$bundle_id" iconSize -float 40
relaunch
# Chill, for the side dock's tall Spotify tile.
osascript -e 'tell application "System Events" to key code 19 using {control down, option down}' || true
swift scripts/fake-spotify-track.swift || true
swift scripts/move-mouse.swift 30 400 || echo "couldn't move the pointer"
sleep 2
screencapture -x "$out/6-left-position.png"
osascript -e 'tell application "System Events" to key code 18 using {control down, option down}' || true  # ⌃⌥1, back to Work
defaults delete "$bundle_id" position
defaults delete "$bundle_id" iconSize
swift scripts/move-mouse.swift -1 500 || true  # out of the way

relaunch -showSettings general
screencapture -x "$out/7-settings-general.png"
relaunch -showSettings profiles
screencapture -x "$out/8-settings-profiles.png"

# The calendar from the date widget (in the active profile, Work).
relaunch -openPopover calendar
screencapture -x "$out/9-calendar.png"

# The Spotify player, with a sample song, playback and search results: CI has no Spotify.
relaunch -openPopover spotify -spotifyTestPlayback 83,241,70,true,false \
  -spotifyTestSearchResponse "$PWD/scripts/sample-spotify-search.json" -spotifySearchQuery "between the bars"
osascript -e 'tell application "System Events" to key code 19 using {control down, option down}' || true
sleep 1
swift scripts/fake-spotify-track.swift || true
sleep 4
screencapture -x "$out/10-spotify-player.png"

# Quitting has to give the system Dock its original settings back.
pkill -TERM -x Dockry
sleep 3
restored_settings=$(dock_settings)
if [[ "$restored_settings" != "$original_settings" ]]; then
  echo "Dock settings after quitting: $restored_settings; expected: $original_settings" >&2
  exit 1
fi
echo "Screenshots saved to $out; the system Dock was restored."
