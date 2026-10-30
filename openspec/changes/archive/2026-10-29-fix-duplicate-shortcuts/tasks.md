# Tasks

## 1. Core

- [x] 1.1 Add `KeyShortcut.sameKeys(as:)` and `KeyShortcut.duplicates(in:)` and verify with new `KeyShortcutTests` cases, including the different-label case

## 2. App

- [x] 2.1 Register only the first of each combination in `HotKeys` and publish the duplicates apart from `taken`, and verify `swift build`
- [x] 2.2 Give `ShortcutRecorder` a `usedBy` lookup, refuse clashing recordings with the owner's name, show the duplicate message, wire it for the switcher and for profiles in `SettingsWindow`, and verify `swift build`
