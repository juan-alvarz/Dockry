# Tasks

## 1. Core

- [x] 1.1 Add `DockLayout.addsVisibleDivider` and verify with `DockLayoutTests` cases for the Default profile (next to a divider, at the end) and between open apps and a widget

## 2. Menu

- [x] 2.1 Provide the check to `DockEditMenu` through the environment and disable Add Divider when it fails, and verify `swift build`
- [x] 2.2 On-screen check: confirm the dock still shows the same items after installing; record that opening the right-click menu needs pointer input this shell doesn't have

On-screen check (installed build): the dock shows the same items as before. Not checked here: the greyed-out Add Divider item itself, since opening a right-click menu needs pointer input this shell does not have; the rule is covered by `DockLayoutTests.testADividerIsOnlyAddedWhereItShows`.
