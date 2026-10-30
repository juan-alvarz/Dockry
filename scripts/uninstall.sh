#!/usr/bin/env bash
# Removes Dockry from this account: quits it (so it gives the macOS Dock back), then moves
# the app, its profiles and data to the Trash and deletes its settings and permissions.
# Usage: scripts/uninstall.sh [--keep-permissions]
#   --keep-permissions  keep Accessibility, Automation and Location grants for the next install
# Left alone: the "Dockry Dev" signing certificate (scripts/install.sh reuses it), Claude
# Code's Keychain item (it's Claude Code's), and a copy in /Applications owned by another account.
set -euo pipefail

bundle_id=com.dockry.Dockry
keep_permissions=false
case "${1:-}" in
  "") ;;
  --keep-permissions) keep_permissions=true ;;
  *) echo "Usage: scripts/uninstall.sh [--keep-permissions]" >&2; exit 2 ;;
esac

# 1. Quit the normal way: Dockry restores the macOS Dock and puts parked windows back.
if pgrep -xq Dockry; then
  echo "Quitting Dockry…"
  osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || pkill -TERM -x Dockry || true
  for _ in {1..20}; do pgrep -xq Dockry || break; sleep 0.5; done
  if pgrep -xq Dockry; then
    echo "Dockry didn't quit. Quit it from its menu bar item, then run this again." >&2
    exit 1
  fi
fi

# 2. If Dockry still had the macOS Dock hidden (it crashed, say), give the Dock back before
#    its saved settings are deleted.
if [[ "$(defaults read "$bundle_id" systemDockHidden 2>/dev/null || echo 0)" == 1 ]]; then
  echo "Showing the macOS Dock again…"
  defaults delete com.apple.dock autohide-delay 2>/dev/null || true
  killall Dock || true
fi

# 3. To the Trash, so anything can still be put back (profiles, fresh profiles' app data).
stamp=$(date +%Y%m%d-%H%M%S)
trash() {
  [[ -e "$1" ]] || return 0
  if [[ ! -O "$1" ]]; then
    echo "Skipping $1: it belongs to another account."
    return 0
  fi
  mv "$1" "$HOME/.Trash/$(basename "$1") $stamp"
  echo "Moved to the Trash: $1"
}
trash /Applications/Dockry.app
trash "$HOME/Applications/Dockry.app"
trash "$HOME/Library/Application Support/Dockry"
trash "$HOME/Library/Caches/$bundle_id"
trash "$HOME/Library/HTTPStorages/$bundle_id"
trash "$HOME/Library/Saved Application State/$bundle_id.savedState"

# 4. Settings, including those saved under Dockry's identifier before 0.0.9.
for domain in "$bundle_id" io.github.juan-alvarz.Dockry; do
  defaults delete "$domain" 2>/dev/null && echo "Deleted settings: $domain" || true
done

# 5. Privacy permissions (Accessibility, Automation, Location…).
if ! $keep_permissions; then
  tccutil reset All "$bundle_id" >/dev/null && echo "Reset privacy permissions for $bundle_id"
fi

echo "Done. If Dockry was set to open at login, remove it in System Settings › General › Login Items."
