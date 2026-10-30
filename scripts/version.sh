#!/usr/bin/env bash
# Prints Dockry's version: the first "## <version>" heading in CHANGELOG.md.
# With --notes, prints that version's notes instead (the lines up to the next "## " heading),
# with wrapped lines joined: GitHub shows every line break in release notes as a break.
set -euo pipefail
cd "$(dirname "$0")/.."
awk -v notes="${1:-}" '
  # A line that starts a block of its own instead of continuing the one before it.
  function starts_block(line) {
    return line ~ /^[[:space:]]*([-*>#]|[0-9]+\.)[[:space:]]/ || line ~ /^[[:space:]]*#/
  }
  function flush() { if (paragraph != "") { print paragraph; paragraph = "" } }
  /^## / {
    if (found) exit
    if ($2 ~ /^[0-9]+(\.[0-9]+)*$/) { found = 1; if (notes != "--notes") { print $2; exit } }
    next
  }
  !found { next }
  /^[[:space:]]*```/ { flush(); print; fenced = !fenced; next }
  fenced { print; next }
  /^[[:space:]]*$/ { flush(); print ""; next }
  {
    if (paragraph == "" || starts_block($0)) {
      flush()
      paragraph = $0
    } else {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      paragraph = paragraph " " line
    }
  }
  END {
    flush()
    if (!found) { print "No version heading in CHANGELOG.md" > "/dev/stderr"; exit 1 }
  }
' CHANGELOG.md
