## Why

On 2026-11-02 the user found, in one sitting, that Zen opened from Raycast switched to the
profile holding its windows, that the second screen showed another profile's wallpaper,
and that the dock's profile button showed a speaker for the wrong profile. Fixes kept
breaking other cases because the rules sat in untested AppKit code, were spread over two
modes (apps, windows), and guessed from event timing whether a launcher was involved.

A detour that day gave each profile a macOS desktop (Spaces) instead. It needed desktops
created in Mission Control, shortcuts turned on and windows moved by hand, and the user
found it awful. This change goes back to workspaces of Dockry's own, as AeroSpace does:
every window stays on one macOS desktop and other profiles' windows are parked off screen,
with one mode and one rule for an app coming forward, however it came.

## What Changes

- **BREAKING** One setting, "Give each profile its own windows", on by default, replaces
  "Give each profile its own open apps" and "Open a new app instance". Apps are never
  hidden; each window is in the profile active when it opened, and switching parks the
  other profiles' windows.
- An app coming forward with windows only in other profiles gets a new window here (its
  New Window), whether from the dock, Raycast, ⌘Tab or a link. No launcher detection.
- After a switch, the keyboard goes to the profile's front window (or Finder), not to a
  window that just went off screen.
- Wallpapers: every profile's picture is set on every screen at each switch, at launch and
  when a screen is plugged in. A profile without one shows the macOS default picture;
  nothing is learned from the screens. Once, profiles without a wallpaper get the picture
  showing at the update as theirs.
- The dock's profile button shows no speaker; sound marks the profiles of the app's windows.

## Impact

- Specs: `profile-apps`, `wallpapers`, `fresh-profiles`.
- Code: `Sources/DockryCore/ProfileWindowRecords.swift`, `ProfileAppRules.swift` (new, with
  tests); `Sources/Dockry/ProfileApps.swift`, `ProfileWindows.swift`, `AppOpening.swift`,
  `Wallpapers.swift`, `AppDelegate.swift`, `SettingsStore.swift`, `SettingsWindow.swift`,
  `DockView.swift`.
- Saved data: `profileWindows` keeps its format; `opensNewAppInstances`, `ownWallpapers`,
  `wallpapersSetByDockry` deleted.
