# Known issues

Open or recurring bugs and platform limits, newest first. Fixed entries stay when the
cause wasn't obvious, so the same bug isn't fixed twice. An issue is fixed only once it
was checked in the running app.

## Open

### 2026-11-12 · Code review fixes not checked on screen
A review found the profile windows code wrong in ways the tests couldn't show; the fixes
build and pass the tests, and none has been checked in the running app. To check:
- ⌘Tab to Spotify (or any app without New Window) from another profile: its window comes here.
- Close an app's last window in a profile, then click it in the dock: a new window opens.
- Switch with Zen in front and a Zen window in both profiles: typing goes to the one showing.
- Unplug or plug in a screen: the other profiles' windows stay away, and come back on switching.
- Two screens of different heights: windows park (no `didn't move off screen` in the log).
- A fresh profile: a password prompt or a menu bar app coming forward doesn't switch profile.
- Edit profiles.json by hand, then switch profile without **Reload from File**: the edit is kept.
- With a minimized window in another profile: no yellow dot and no row for it in this one.

### 2026-11-12 · Still open after the review
- **New Window is found by its English title.** In another language, or where the item is in
  a submenu, the app's front window is brought here instead of a new one opening.
- **Opening a document in an app whose windows are all elsewhere** (and that has no New
  Window) also brings its front window here: the app comes forward before the document opens.
- **A crash or `kill -9` leaves windows parked and the macOS Dock hidden** until Dockry is
  opened again; SIGTERM, SIGINT and SIGHUP put them back. Nothing relaunches Dockry.
- **An app that isn't answering holds a switch up for a second**: Accessibility is asked on
  the main thread, with a 1 s timeout.
- **A profile's `desktop` works against parking**: Accessibility lists only the desktop
  showing. Dockry now looks again half a second after the desktop changes; until then the
  other profiles' windows on that desktop show.

### 2026-11-03 · Claude's window shows in every profile
**Symptom:** the Claude desktop app's window stays on screen after switching away from
its profile; the dock correctly hides Claude's icon.
**Cause:** the Claude process answers every Accessibility request with `-25211`
(`kAXErrorAPIDisabled`), Dockry's included; Terminal, Zen, Zed and Shortty answer normally.
Setting `AXManualAccessibility` (Electron's switch) also returns `-25211`. That process had
been running since login; a stuck Accessibility link since launch is suspected, not confirmed.
**Workaround:** quit and reopen Claude (unverified). Dockry logs
`Dockry windows: Claude has windows on screen that Accessibility doesn't list (error -25211)`.
**Status:** open. If a fresh Claude still refuses, the only tool left is hiding the app
(decisions, "No hidden apps").

### 2026-11-03 · Mission Control shows every profile's windows
**Symptom:** in Mission Control, other profiles' parked windows show next to the active
profile's.
**Cause:** parked windows keep one point on screen on the same desktop. Regression in
0.3.0: before, window mode hid apps with no window in the profile, so Mission Control
skipped them.
**Fix planned:** hide apps with no window in the active profile; park only apps with
windows in several profiles.
**Status:** open.

### 2026-11-02 · Sound in two profiles
An app with windows in two profiles marks both as playing: Core Audio reports the process,
not the window or tab. No fix known.

### 2026-11-02 · Profiles are keyed by name
App owners, window records, fresh app data and the active profile all use the profile's
name, so every rename must be followed by hand (`ProfileStore.renamed`). A rename made by
hand in profiles.json reads as a removed profile: its apps and windows go to the active
one. Fix idea: stable profile ids.

### 2026-10-29 · Unverified on screen
"Keep windows out of the dock's space" was reported buggy and never re-checked with the
user. Widget magnification was never seen working (the pointer can't be moved from a shell).

### 2026-10-29 · Small open findings
- The menu shows ⌃⌥Space next to Profile Switcher; it only works while the menu is open
  but reads as a global shortcut.
- The fresh-profile removal alert says "This will remove all the data associated, you want
  to proceed?", and its checkbox inverts the default.
- Fresh profiles `a/b` and `a-b` share one data folder (`/` becomes `-`).
- The profile switcher has no scrolling, so many profiles outgrow the screen; digits pick 1–9 only.
- `SpotifyPlayer.play(uri:)` strips `"` but not `\` from the AppleScript string (the URI
  comes from Spotify's API).
- One `SpotifyPlayer` per dock: docks on several screens each poll while their popover is open.
- `DockView.dropGap` writes to `pointer` during `body`.

## Platform limits

- **Accessibility lists only windows on desktops that are showing.** Windows on another
  macOS desktop aren't seen, so they can't be recorded or parked until it shows; Dockry
  looks again when the desktop changes.
- **macOS won't move a window wholly off screen.** Parking leaves one point visible, on a
  screen, under one of its bottom corners; full-screen windows aren't parked; some
  windows refuse to move at all (logged `Dockry windows: window N didn't move off screen`).
- **macOS can't hide a single window**: only whole apps, or moving windows.
- **No public API for desktops (Spaces).** Desktop switching posts the user's own "Switch to
  Desktop N" shortcut: it needs that shortcut on and Accessibility.
- **Only the macOS Dock changes the area windows get** (zoom, where new windows go).
  `WindowSpaceKeeper` moves or shrinks windows after the fact instead.
- **Hiding the macOS Dock** is `autohide` plus `autohide-delay` 1000 and `killall Dock`. The
  user's values are kept until a restore succeeds, so a crash never loses them.
- **`~/.Trash` can't be listed without Full Disk Access.** Its entry count and whether
  `.DS_Store` exists can be read; the Trash widget polls that every 2 s.
- **No generic Now Playing:** the private framework stopped working for third-party apps
  in macOS 15.4. Apple Music catalog search needs a MusicKit developer token, so only
  library search exists.
- **Claude usage endpoint** (`api.anthropic.com/api/oauth/usage`) is undocumented and
  rate-limits hard: after a 429, wait 30 min. The refresh token is single-use, so renew only
  when Claude Code's Keychain item can be written back.
- **Private APIs in use**, each degrading to nothing: `_AXUIElementGetWindow`,
  `responsibility_get_pid_responsible_for_pid`, `SACSwitchToUser`,
  `SACSwitchToLoginWindow`, `CGSSetConnectionProperty("SetsCursorInBackground")`.

## Fixed, cause worth remembering

### 2026-11-02 · Second screen kept another profile's wallpaper
**Cause:** "the user's own picture" was learned from what screens showed; one screen still
showing Coffee's picture made it the user's for good. **Fix:** nothing is learned from
screens (decisions, "Wallpapers without memory"). Fixed.

### 2026-11-02 · Zen opened from Raycast switched profiles
**Cause:** the fix guessed the order of activation events; macOS reports them the other
way. **Fix:** one rule from window locations only. Fixed in code; the user's Raycast and
⌘Tab checks are still due.

### 2026-10-29 · Renaming a profile moved its apps and stranded its windows
**Cause:** the library sink sent owners of a name that no longer exists to the *active*
profile, window records never followed renames, and the name field renamed on every
keystroke. **Fix:** explicit rename events, and the name commits when editing ends. Fixed.

### 2026-10-29 · App or window in the wrong profile after a Mac restart
**Cause:** saved by pid only, and pids and window numbers are reused. **Fix:** pid +
launch time for apps; window records also check the pid. Fixed.

### 2026-10-29 · Rectangle moved the dock
**Cause:** the dock is an `NSPanel` whose frame Accessibility exposes as settable, and
Dockry is the active app while a popover is open, so tools acting on the front app's window
reached it. **Fix:** setters refused plus snap-back. Fixed.

### 2026-10-29 · Weather showed °F with "System" chosen
**Cause:** `AppleTemperatureUnit` unset falls back to the region. **Fix:** Celsius or
Fahrenheit only. Fixed.

### 2026-10-28 · Ghost "togglers" over the dock
**Cause:** the macOS Dock showing under Dockry's. **Fix:** the Hide macOS Dock option. Fixed.
