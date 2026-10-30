# Tasks

## 1. Core

- [x] 1.1 Add `WidgetKind.trash` with its `WidgetInfo` and catalog place, and `TrashState.isFull`, and verify with `swift test` (catalog tests plus new Trash state cases)

## 2. Widget

- [x] 2.1 Add `TrashMonitor`, `TrashWidget` (icon, click to open, menu with Open and Empty Trash… behind a confirmation) and the optional widget menu in `DockWidget`/`DockView`, and verify `swift build`
- [x] 2.2 Route Finder drops over the Trash widget to `FileManager.trashItem`, with a highlight and no gap, and verify `swift build`
- [x] 2.3 Update README (widget list, `widget:trash`) and CHANGELOG, and verify the README lists `trash`

## 3. On-screen check

- [x] 3.1 Install, add the Trash widget to the active profile, and confirm by screenshot that it shows the full icon while the Trash has items and that Settings › Widgets lists Trash; record that dropping and emptying can't be exercised from this shell

On-screen check (installed build): the Trash widget shows at the end of the dock with the full icon while the Trash has items. Not checked here: the Settings › Widgets list (the window was behind another app; the list comes from `WidgetCatalog.all`, covered by `WidgetInfoTests`), dropping files on it and Empty Trash… (both need pointer input; emptying is permanent, so it was deliberately not run).
