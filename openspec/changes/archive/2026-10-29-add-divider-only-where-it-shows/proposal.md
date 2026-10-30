# Proposal

## Why

Add Divider often does nothing visible. The dock hides dividers with nothing to separate
(at either end, or next to another divider), and Add Divider inserts right after the item
clicked. In the Default profile (Finder, divider, open apps) every place it can go is
next to the existing divider or at the end, so the user's dividers pile up hidden in
profiles.json.

## What Changes

- Add Divider is greyed out in a right-click menu when a divider there would be hidden.
- When it's enabled, the new divider always shows.
- Hiding dividers that have nothing to separate stays as it is.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dock-contents`: adds a requirement that Add Divider is only enabled where the divider
  would show.

## Impact

- `Sources/DockryCore/DockLayout.swift` (would a divider show) and tests.
- `Sources/Dockry/DockView.swift` (`DockEditMenu`), `FolderStack.swift` callers through the
  environment.
