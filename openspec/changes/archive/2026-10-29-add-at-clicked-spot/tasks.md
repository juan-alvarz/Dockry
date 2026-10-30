# Tasks

## 1. Clicked spot

- [x] 1.1 Record the right-click location in `DockHostingView`/`DockPointer`, make `DockEditMenu` take its index lazily, compute the background's index from the click with `DockLayout.dropGap`/`itemIndex(insertingAt:)`, and verify `swift build` and `swift test`

## 2. On-screen check

- [x] 2.1 Install and confirm by screenshot the dock is unchanged; record that right-clicking needs pointer input this shell doesn't have, so the user checks Add Divider between Zed and the open apps

On-screen check (installed build): the dock shows the same items as the profile. Not checked here: right-clicking the background and choosing Add Divider, which needs pointer input; the click is recorded with a local right-click monitor (not a view override, which a subview could intercept), and the gap math is the tested Finder-drop code.
