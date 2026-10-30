# Design

## Context

`ProfileApps` keeps `owners: [pid: profileName]`; `ProfileWindows` keeps records with a
`profile` name. Both only learn about the library through `store.$library`. After a
change, `ProfileApps` reassigns owners whose name no longer exists to the active profile,
which is right for a removed profile and wrong for a renamed one. `ProfileWindows` never
updates names. A rename can't be recovered from two library snapshots reliably (a rename
and a remove + add look the same), but `ProfileStore.updateProfile` knows both names.

## Goals / Non-Goals

**Goals:** renames carry apps, windows and fresh data along; one rename per edit.

**Non-Goals:** detecting renames made by hand in profiles.json (Reload from File). Those
still fall back to the active profile, as a removed profile does.

## Decisions

- **Explicit rename events.** `ProfileLibrary.updateProfile` returns the final name.
  `ProfileStore` publishes `renamed: PassthroughSubject<(from: String, to: String), Never>`
  after storing the library. Alternative considered: diffing old and new profile lists by
  position — rejected, it guesses wrong when profiles are reordered in the same change.
- **Followers apply it synchronously.** `ProfileApps` maps owners `from → to` and tells
  `ProfileWindows.rename(from:to:)`. The library sink that reassigns missing owners is
  delivered later on the run loop, so by then nothing carries the old name.
- **Commit-on-end name field.** The editor keeps a `@State` draft, commits on `onSubmit`,
  on losing focus and on `onDisappear`; `ProfilesSettings` gives the editor
  `.id(selectedName)` so selecting another profile ends the edit and starts a fresh draft.
  After a refused rename the draft resets to the stored name.

## Risks / Trade-offs

- [A rename event arrives while a switch is in progress] → the mapping is a pure rename of
  names, independent of which profile is active.
- [onDisappear commit after the profile was removed] → `updateProfile` ignores unknown
  names, so it's a no-op.
