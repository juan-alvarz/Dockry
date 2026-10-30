# Tasks

## 1. Core

- [x] 1.1 Add `plateau` to `DockMagnification.Item` and measure distance from the plateau's edge, and verify with `DockMagnificationTests` cases for a wide item magnified fully at its end and unchanged icon behavior

## 2. Dock

- [x] 2.1 Wrap widgets in a scaling wrapper, mark them as magnifying with their plateau in `DockRowLayout`, and verify `swift build` and that the existing magnification tests still pass
- [x] 2.2 Check in the running app that a widget grows under the pointer and stays clickable, or record why it couldn't be checked

Note on 2.2: not checked here; it needs the installed build and a pointer over the dock. To check: turn on magnification, hover the weather or Spotify widget, confirm it grows and its buttons still work.
