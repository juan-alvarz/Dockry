# Dockry

A macOS 14+ menu bar app that runs a dock next to the system Dock. Swift package, no
Xcode project, no third-party dependencies. `DockryCore` is Foundation-only logic with
XCTest coverage; the `Dockry` target is AppKit/SwiftUI glue and has no tests.

## Project memory

`docs/memory/` holds what the code doesn't show: `decisions.md`, `known-issues.md` and
`changelog-notes.md`.

- Read docs/memory/ before starting any non-trivial change.
- After a critical change, a decision (including a rejected approach) or a bug that
  persists or was hard to find, add an entry to the matching file in the same commit.
- Update or mark entries that become wrong. Never leave a stale one.
- Don't record what the code, tests or git log already make obvious.
- Real-device behavior wins over specs: an issue is fixed only after it has been checked
  in the running app, not because the tests pass.

## Project rules

- Rules that can be pure go in DockryCore, with a test for each case the user reported.
  The app target only reads macOS and applies the answer. `swift test` must keep passing.
- Dockry is never the active app and never takes keyboard focus, except while one of its
  popovers or Settings is open.
- The dock behaves like the macOS Dock toward other apps: window managers, snapping tools,
  ⌘Tab and Mission Control must never move, resize, maximize or focus it.
- Never leave the user worse off after quitting or crashing: the macOS Dock restored,
  parked windows put back, a hand-edited profiles.json never overwritten.
- Optional permissions (Accessibility, Automation, Location, Keychain) only unlock
  features; everything else works without them, and the UI says what's missing.
- profiles.json stays hand-editable and backward compatible: lenient decoding, older
  files keep loading.
- Installing works without admin rights: `scripts/install.sh --profile-only`.
- Log what can fail on the Mac with NSLog and a `Dockry` prefix (`Dockry windows:` for
  window moves), so `log show` output can be sent back.
- User-facing text follows the README's plain, short style. A user-visible change also
  updates README.md and adds a line to CHANGELOG.md.
- Never add AI attribution to commits, PRs, code or docs.
