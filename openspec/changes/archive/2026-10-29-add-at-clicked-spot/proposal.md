# Proposal

## Why

Right-clicking the dock's background between two icons and choosing Add Divider puts the
divider at the very end of the dock, not where the user clicked. The background menu
always adds at the end.

## What Changes

- Add Divider, Add Folder… and Add Widget in the dock background's menu add at the spot
  that was right-clicked: in front of the first item past the click along the dock, or at
  the end when the click is past the last item.
- Open apps that aren't pinned form one group; a click inside it adds in front of the group.
- Item menus keep adding right after the item clicked.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dock-appearance`: "Dock background menu" adds at the clicked spot instead of the end.
- `dock-contents`: the "Divider at the end" scenario becomes "Divider where the background
  was clicked".

## Impact

- `Sources/Dockry/DockPanel.swift` (records where a right-click happened),
  `DockPointer.swift`, `DockView.swift` (`DockEditMenu` takes its index lazily; the background
  menu computes it from the click), `FolderStack.swift` (call site).
- Uses the existing `DockLayout.dropGap` and `DockLayout.itemIndex(insertingAt:)`, already
  unit tested for drops from Finder.
