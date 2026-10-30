# Proposal

## Why

With magnification on, app and folder icons grow under the pointer but widgets (Clock,
Calendar, Spotify, Weather, Claude Usage, Switch User) stay flat. Between growing icons
they look inert, unlike the rest of the dock.

## What Changes

- Widgets magnify like app icons: the one under the pointer grows to the magnified size
  (by the same factor as an icon), its neighbors less, and everything stays clickable.
- A wide widget counts as "under the pointer" anywhere along it, not only at its center,
  so hovering its edge magnifies it fully instead of barely.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dock-appearance`: "Magnification" now covers widgets, and wide items grow fully
  anywhere under the pointer.

## Impact

- `Sources/DockryCore/DockMagnification.swift` (a full-size zone per item) and tests.
- `Sources/Dockry/DockView.swift`, `DockRowLayout.swift` (widgets marked as magnifying,
  scaled to the size the layout gives them).
