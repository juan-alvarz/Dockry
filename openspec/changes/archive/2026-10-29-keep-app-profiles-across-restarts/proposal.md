# Proposal

## Why

Which profile each open app belongs to is saved by process id only. After the Mac
restarts, process ids are reused, so an app that Dockry finds already running at launch
can be put in an unrelated profile, and a reused window number can inherit another
window's profile (finding 5).

## What Changes

- Saved app ownership records each process's launch time too, and a saved entry applies
  only to the same process: same id and same launch time.
- A saved window record applies only to a window of the same process it was saved for.
- Entries in the old, id-only format are dropped once; those apps join the active
  profile, as apps that open while Dockry runs do.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `profile-apps`: adds a requirement that ownership survives Dockry restarting but not
  another process reusing the id.

## Impact

- `Sources/DockryCore` new `AppOwnership.swift` (saved entry, matching) and tests.
- `Sources/Dockry/ProfileApps.swift` (save/load), `ProfileWindows.swift` (pid check).
- UserDefaults: new key `appOwners`; the old `appProfiles` key is removed on first launch.
