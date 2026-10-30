# Proposal

## Why

On first launch Dockry creates Work and Chill with the Claude usage, weather, Spotify and
users widgets and desktops 1 and 2. Those widgets ask for Keychain, Location and
Automation access before the user has chosen any of them, so a new install opens with a
string of permission prompts.

## What Changes

- **BREAKING** (first launch only): without saved profiles, Dockry starts with a single
  profile named Default, with the house symbol and Finder pinned, and nothing else: no
  widgets, no desktop, no color, no shortcut, no wallpaper.
- The same single profile is what Dockry falls back to when profiles.json can't be read.
- Existing profiles.json files are untouched.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `profiles`: the "Default profiles" requirement changes from Work and Chill to one
  Default profile.

## Impact

- `Sources/DockryCore/Profile.swift` (`Profile.defaults`), `ProfileLibraryTests`.
- README wording about the default profiles; CHANGELOG.
- No migration: only installs without a profiles.json are affected. CI's screenshots
  write their own profiles.json, so they don't change.
