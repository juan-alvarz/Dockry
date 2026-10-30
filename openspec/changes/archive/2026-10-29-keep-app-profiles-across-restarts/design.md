# Design

## Context

`ProfileApps` saves `appProfiles: [String(pid): profile]` on every change and, at
launch, looks up every running app by pid. `ProfileWindows` saves
`[String(windowNumber): Record(profile, pid, home)]` and drops records whose window the
window server no longer has, but `scan` keeps a record for a number that now belongs to
another process's window.

## Goals / Non-Goals

**Goals:** a saved entry only ever applies to the process it was made for.

**Non-Goals:** keeping ownership across a Mac restart (processes are new then).

## Decisions

- **Launch time as the second key.** `NSRunningApplication.launchDate` is stable for a
  process's life and differs for a reused pid. `DockryCore.AppOwnership` holds the saved
  entries (`pid`, `launchedAt`, `profile`, Codable) and
  `profile(forPID:launchedAt:)`, matching launch times within one second (dates
  round-trip through JSON). An app without a launch date matches only an entry saved
  without one. Alternative considered: dropping all saved ownership at login — rejected,
  it loses ownership whenever Dockry restarts.
- **New key, old one removed.** Saved as JSON under `appOwners`; `appProfiles` is
  deleted at launch rather than migrated, since its entries can't be checked.
- **Window records check the pid.** In `ProfileWindows.scan`, a record whose pid isn't
  the scanned app's is replaced by a new record for the current owner.

## Risks / Trade-offs

- [Updating Dockry drops the old ownership once] → those apps join the active profile,
  the same as before Dockry ever saw them.
