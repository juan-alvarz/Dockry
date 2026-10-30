# Proposal

## Why

Renaming a profile that isn't active hands its open apps to the active profile, and in
window mode leaves its windows parked off screen until Dockry quits. The name field in
Settings renames on every keystroke, so typing a name repeats that damage letter by
letter, rewrites profiles.json, re-registers shortcuts and moves a fresh profile's app
data each time. (Findings 1–3 in `openspec/notes/findings.md`.)

## What Changes

- A renamed profile keeps its open apps and its windows, whichever profile is active.
- The profile editor renames only when the user finishes editing the name (Return,
  leaving the field, or switching to another profile), not on each keystroke.
- `ProfileLibrary.updateProfile` returns the profile's name after the change, so callers
  can tell a rename happened without comparing lists.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `profile-apps`: adds a requirement that renaming keeps a profile's apps and windows.
- `app-settings`: adds a requirement that the editor renames once editing ends.

## Impact

- `Sources/DockryCore/ProfileLibrary.swift` (return value), its tests.
- `Sources/Dockry/ProfileStore.swift` (publishes renames), `ProfileApps.swift`,
  `ProfileWindows.swift` (follow renames), `SettingsWindow.swift` (name field).
- No change to profiles.json or saved defaults formats.
