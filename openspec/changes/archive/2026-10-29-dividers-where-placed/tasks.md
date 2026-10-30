# Tasks

## 1. Core

- [x] 1.1 Change `DockLayout.elements` to keep placed dividers and drop only those cut off by hidden items, remove `addsVisibleDivider`, and verify with updated `DockLayoutTests` (adjacent dividers, end dividers, hidden-only gaps)

## 2. Menu

- [x] 2.1 Remove the environment check and the disabled state from `DockEditMenu`, and verify `swift build`

## 3. On-screen check

- [x] 3.1 Install and confirm by screenshot that the user's two side-by-side dividers before the Trash now both show; record that clicking Add Divider needs pointer input this shell doesn't have

On-screen check (installed build): the two dividers the user placed side by side before the Trash both show. Not checked here: choosing Add Divider in a right-click menu (needs pointer input); the menu item no longer has any disabled state, and placement rules are covered by `DockLayoutTests`.
