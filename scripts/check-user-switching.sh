#!/usr/bin/env bash
# CI only: goes to the login window with the private call Dockry uses for Fast User
# Switching, then checks that this session left the screen. Run it last; it can't switch back.
set -euo pipefail
cd "$(dirname "$0")/.."
console_owner() { stat -f %Su /dev/console; }
before=$(console_owner)
swift scripts/switch-user.swift
sleep 5
after=$(console_owner)
echo "Screen owner before: $before; after switching: $after"
if [[ "$after" == "$before" ]]; then
  echo "Switching users didn't take this session off the screen." >&2
  exit 1
fi
