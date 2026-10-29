#!/usr/bin/env bash
# Prints Dockry's version: the first "## <version>" heading in CHANGELOG.md.
# With --notes, prints that version's notes instead (the lines up to the next heading).
set -euo pipefail
cd "$(dirname "$0")/.."
awk -v notes="${1:-}" '
  /^## / { if (found) exit; if ($2 ~ /^[0-9]+(\.[0-9]+)*$/) { found = 1; if (notes != "--notes") { print $2; exit } }; next }
  found { print }
  END { if (!found) { print "No version heading in CHANGELOG.md" > "/dev/stderr"; exit 1 } }
' CHANGELOG.md
