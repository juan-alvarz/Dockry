# Design

## Context

`~/.Trash` is protected: without Full Disk Access, listing it fails with "Operation not
permitted". Its entry count (`URLResourceKey.directoryEntryCountKey`) and the existence of
a named file inside it (`.DS_Store`) can still be read. Finder drops are handled in AppKit
by `DockHostingView`, which only accepts apps and folders and hands them to the dock's
gap. Widget right-click menus are built by `DockView` (Remove + add items).

## Goals / Non-Goals

**Goals:** the Dock's Trash behavior without Full Disk Access.

**Non-Goals:** dragging dock items onto the Trash to remove them; ejecting volumes.

## Decisions

- **State by count.** `TrashState.isFull(entryCount:hasDSStore:)` in `DockryCore`, polled
  every 2 seconds while a widget is visible (one `stat`-level read; no file events are
  available without access to the folder). A shared `TrashMonitor` counts visible widgets
  like the weather and Claude monitors.
- **Drops.** `DockPointer` learns whether a drag is over the Trash widget's frame
  (`widgetFrames["widget:trash"]`). Over it, `DockHostingView` accepts any file URLs with
  the `.delete` operation, opens no gap, and `performDragOperation` calls
  `FileManager.trashItem` for each. Elsewhere, drops behave as before.
- **Menu.** `DockWidget` gets an optional `makeMenu`, shown at the top of the widget's
  right-click menu by `DockView`.
- **Emptying.** An `NSAlert` ("Are you sure you want to permanently erase the items in
  the Trash?", destructive Empty Trash button) and then
  `tell application "Finder" to empty trash` through the existing `AppleScript.run`, so
  Finder does the deleting the way the Dock does. A failure shows an alert pointing to
  Privacy & Security › Automation.

## Risks / Trade-offs

- [Polling] → only while a Trash widget is on screen, one directory read every 2 s.
- [Permanent deletion] → always behind Dockry's own confirmation, default button Cancel.
