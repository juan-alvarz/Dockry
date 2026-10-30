# Proposal

## Why

The macOS Dock ends with the Trash; Dockry has none, so deleting by drag or emptying the
Trash means going back to Finder. A Trash widget closes the most visible gap with the
Dock, and needs no permission to show or to take dropped files.

## What Changes

- New built-in widget, Trash (`widget:trash`): the empty or full Trash icon, updated as the
  Trash changes.
- Dropping files or folders from Finder onto it moves them to the Trash.
- Clicking it opens the Trash in Finder; its right-click menu adds Open and Empty Trash…,
  which asks first and then has Finder empty it.
- Widgets can add their own items to their right-click menu in the dock.

## Capabilities

### New Capabilities

- `trash-widget`: the Trash in the dock: its state, dropping onto it, opening and emptying it.

### Modified Capabilities

- `widgets`: the catalog gains Trash.
- `profiles-file`: `trash` becomes a valid widget name.

## Impact

- `Sources/DockryCore` (`WidgetKind.trash`, its `WidgetInfo`, catalog order, Trash state) and tests.
- `Sources/Dockry/Widgets/Trash/` (new), `WidgetView.swift` (optional widget menu),
  `DockView.swift`, `DockPanel.swift` and `DockPointer.swift` (drops onto the Trash).
- Emptying uses Finder through AppleScript, so macOS asks once to let Dockry control Finder.
