# Design

## Context

`DockLayout.elements` drops dividers at either end and next to another shown divider.
`DockEditMenu` (in every item's right-click menu) inserts a divider at the clicked item's
index + 1, or at the end from the dock's background, without knowing whether it will show.

## Goals / Non-Goals

**Goals:** Add Divider never silently does nothing.

**Non-Goals:** removing hidden dividers already saved; changing where dividers go.

## Decisions

- `DockLayout.addsVisibleDivider(items:at:running:showsUnpinned:isShown:)` compares the
  number of shown dividers with and without the new one, using the same inputs the dock
  uses. Pure and unit tested.
- `DockView` puts a `(Int) -> Bool` check in the environment for the active profile and its
  running apps; `DockEditMenu` reads it and disables Add Divider. Alternative considered:
  hiding the item — rejected, a greyed item tells the user why it isn't available.

## Risks / Trade-offs

- [Open apps change while the menu is open] → the menu reflects the moment it opened, like
  any context menu.
