#!/bin/bash
# Build, install to /Applications, launch. Creates the signing certificate on first run.
#   scripts/install.sh                 # /Applications/Dockry.app
#   scripts/install.sh --profile-only  # ~/Applications/Dockry.app, just this account (no admin rights needed,
#                                      # and another account's copy in /Applications is never touched)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="/Applications/Dockry.app"
case "${1:-}" in
  "") ;;
  --profile-only) APP="$HOME/Applications/Dockry.app" ;;
  *) echo "Usage: scripts/install.sh [--profile-only]" >&2; exit 2 ;;
esac

scripts/make-signing-cert.sh # no-op once the certificate exists
scripts/bundle.sh

# -u: with fast user switching, another account's Dockry may be running too.
pkill -u "$USER" -x Dockry 2>/dev/null || true
# Wait for it to exit; opening while it's still quitting fails with LaunchServices error -600.
for _ in $(seq 25); do pgrep -u "$USER" -x Dockry >/dev/null || break; sleep 0.2; done
mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
ditto build/Dockry.app "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
codesign -dr - "$APP" 2>&1 | grep designated
# Launch Services can still be registering the replaced bundle; error -600 means "try again in a moment".
for attempt in 1 2 3 4 5; do open "$APP" 2>/dev/null && break; sleep 0.5; done
sleep 1; pgrep -u "$USER" -x Dockry >/dev/null || { echo "Dockry did not start; run: open $APP"; exit 1; }
echo "Installed and launched $APP"
