## 1. Core

- [x] 1.1 `ProfileWindowRecords`: window → profile, park plan, restart, old saved format (11 tests)
- [x] 1.2 `ProfileAppRules`: dock, coming forward (one rule for every way in), dock click, sound, fresh profiles (21 tests)

## 2. App

- [x] 2.1 `ProfileWindows` moves windows for the records; `ProfileApps` applies the rules, hides nothing, keyboard to the profile's front window after a switch
- [x] 2.2 `AppOpening` uses the rules; one setting, on by default
- [x] 2.3 `Wallpapers`: profile picture or macOS default on every screen; once, profiles without one get the current picture
- [x] 2.4 Desktop-per-profile code from earlier that day deleted (`DesktopSync`, setup, auto-assigned desktops)

## 3. Checks without the user's Mac

- [x] 3.1 `swift test` (150 tests), `swift build -c release`

## 4. The user's checks

- [ ] 4.1 Raycast: in Projects, open Zen while its only window is in Chill: a new window in Projects
- [ ] 4.2 ⌘Tab to Zen in the same case: a new window in Projects
- [ ] 4.3 Switch Projects ↔ Chill: only each profile's windows on both screens, keyboard in a window you can see
- [ ] 4.4 Wallpaper on both screens follows the profile; Projects keeps the kitty
- [ ] 4.5 Quit Dockry: every window back on screen
- [ ] 4.6 If something fails: `log show --last 10m --predicate 'process == "Dockry"' | grep "Dockry windows"`
