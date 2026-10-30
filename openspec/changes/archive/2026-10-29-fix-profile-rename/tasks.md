# Tasks

## 1. Core

- [x] 1.1 Make `ProfileLibrary.updateProfile` return the profile's final name (`@discardableResult`) and verify with new `ProfileLibraryTests` cases for an accepted, a refused and a non-rename change

## 2. Follow renames

- [x] 2.1 Publish `(from, to)` renames from `ProfileStore.updateProfile` and verify the app builds (`swift build`)
- [x] 2.2 Map `ProfileApps.owners` and `ProfileWindows` records from the old name to the new one on each rename, and verify by reading the rename path that the active-profile fallback only sees names that no longer exist

## 3. Name field

- [x] 3.1 Replace the per-keystroke rename in `ProfileEditor` with a draft committed on Return, focus loss and disappear, give the editor `.id(selectedName)`, and verify `swift build` and that renaming selects the renamed profile
