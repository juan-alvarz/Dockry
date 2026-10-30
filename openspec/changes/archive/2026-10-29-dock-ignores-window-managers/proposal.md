# Proposal

## Why

Rectangle's maximize shortcut moved Dockry's dock (finding 20). The macOS Dock is never a
target for window managers, and Dockry's dock must behave the same: it is part of the
desktop, not a window the user arranges.

## What Changes

- Other apps can no longer move, resize, zoom or minimize a dock panel through
  Accessibility.
- If a dock panel is moved anyway, Dockry puts it straight back where it belongs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dock-appearance`: adds a requirement that other apps can't move or resize the dock.

## Impact

- `Sources/Dockry/DockPanel.swift` only. No settings, no saved data.
- The dock stays visible to VoiceOver and other assistive apps; only its frame stops
  being settable.
