# Design

## Context

SwiftUI's `contextMenu` doesn't say where the click happened, and `DockEditMenu` gets a
fixed index; the background passes `items.count`. Finder drops already solve "which gap is
this point in": `DockLayout.dropGap(at:centers:)` and `itemIndex(insertingAt:elements:itemCount:)`.

## Decisions

- `DockHostingView.rightMouseDown` records the click in the window's SwiftUI coordinates
  on `DockPointer.contextClick` before passing the event on, so the menu opens as before.
- `DockEditMenu.index` becomes `() -> Int`, read when an item is chosen. Item menus pass
  their fixed index; the background passes `DockView`'s computation from `contextClick`
  and the elements' current frames (the same centers drops use), falling back to the end.
- Alternative considered: the pointer's last position over the dock — rejected, it moves
  as the pointer travels to the menu.

## Risks / Trade-offs

- [The open-apps group can't be split] → a click inside it adds in front of the group,
  the closest place the profile's items allow.
- [Right-click capture can't be exercised from the implementation shell] → gap math is the
  tested drop code; the click recording is reported unverified.
