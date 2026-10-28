# Dockry

A dock for macOS that changes with what you're doing. Dockry runs next to the system Dock
(the way Raycast runs next to Spotlight) instead of modifying it. It can hide the system
Dock while it runs and gives it back when it quits.

| Work | Chill, with the Spotify widget |
|---|---|
| ![Work profile](docs/screenshots/1-work-profile.png) | ![Chill profile](docs/screenshots/2-chill-profile.png) |
| **Profile switcher (⌃⌥Space)** | **Menu bar** |
| ![Profile switcher](docs/screenshots/3-profile-switcher.png) | ![Menu bar menu](docs/screenshots/4-menu-bar.png) |

The screenshots are taken by CI on a GitHub-hosted macOS machine on every push to `dev`.
Feature branches (`dev-*`) publish theirs to the
[`screenshots`](https://github.com/juan-alvarz/Dockry/tree/screenshots) branch, one folder
per branch, so PRs into `dev` don't carry PNG changes that conflict with each other.
That machine has no Spotify, so CI sends the notification Spotify posts when a song starts
to show the widget with a track.

## What it does

- **A floating dock** at the bottom of the screen, on every desktop. It shows the active
  profile's pinned apps, then any other app that's running, then the profile's widgets.
  Like the system Dock it's exactly as wide as what's in it; if that would be wider than the
  screen, it scrolls sideways instead.
  A dot marks running apps. Click to open or switch to an app. Right-click to keep it in or
  remove it from the profile, show it in Finder, or quit it.
- **Profiles** such as *Work* and *Chill*. Each has its own pinned apps, widgets and desktop.
  Activating a profile swaps the dock's contents and jumps to its desktop.
- **Widgets:** clock, date, Spotify (what's playing, with previous / play-pause / next), and
  users.
- **Fast User Switching:** the users widget shows the Mac's other accounts. Click one to
  switch to it, as you would from the user menu in Control Center. **Switch User** in the
  menu bar menu does the same and also opens the login window.
- **The profile switcher** for Dockry's own profiles, like ⌘Tab. Hold ⌃⌥ and tap Space to move through
  the profiles; let go to switch. A quick ⌃⌥Space flips to the next profile. When it stays
  open (keys already released, or opened from the menu), use the arrows or Tab, 1–9 or
  Return to pick, and Esc to cancel.
- **Other ways to switch:** ⌃⌥1 … ⌃⌥9 jump straight to a profile, and so do the menu bar
  item and the profile button at the left of the dock.
- **Hide macOS Dock** in the menu bar menu. This turns on the system Dock's auto-hide with a
  very long delay, so it never shows up. Your own Dock settings are saved first and put
  back when you turn the option off or quit Dockry.

## Installing

Dockry runs on macOS 14 or later, on Apple silicon and Intel Macs.

1. Download `Dockry-<version>.dmg` from the
   [latest release](https://github.com/juan-alvarz/Dockry/releases/latest) and open it.
2. Drag **Dockry** onto the Applications folder next to it, then eject the disk image.
3. Open it. Dockry isn't notarized by Apple, so the first time macOS says it can't be
   opened. Click **Done**, then go to System Settings › Privacy & Security, scroll down to
   *"Dockry" was blocked*, click **Open Anyway** and confirm. You only do this once per
   version. Or, in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Dockry.app
   ```

Dockry has no icon in the Dock; look for its icon in the menu bar. To quit it, choose
**Quit Dockry** there. To uninstall, quit it and delete the app, plus
`~/Library/Application Support/Dockry` if you want your profiles gone too.

## Using it

1. **Pick a profile:** press ⌃⌥1 for Work or ⌃⌥2 for Chill, or use the menu bar menu or the
   profile button at the left of the dock. Hold ⌃⌥ and tap Space to step through them.
2. **Hide the system Dock** with **Hide macOS Dock** in the menu bar menu, if you want only
   Dockry's dock on screen.
3. **Make the profiles yours:** right-click an app in the dock to keep it in or remove it
   from the current profile. **Edit Profiles…** opens the [profiles file](#profiles-file)
   for widgets, desktops and symbols.
4. **Optional setup**, each explained below: desktop switching needs a keyboard shortcut
   turned on and Accessibility access, user switching needs Fast User Switching turned on,
   and the Spotify buttons need you to allow Automation when macOS asks.

## Building from source

Requires macOS 14 or later and Xcode 15 or later (or the Swift 5.9+ command line tools).

```bash
swift test              # unit tests for the platform-independent logic
scripts/bundle.sh       # builds build/Dockry.app
open build/Dockry.app
```

Don't run `scripts/screenshots.sh` on your own Mac. It's meant for CI: it opens and quits
apps and changes the Dock's settings.

To publish a release, run the **Release** workflow from the Actions tab on `main` with a
version such as `0.0.2`. It tags the commit `Dockry-0.0.2` and attaches a universal
Dockry.app as a disk image and as a zip. Pushing a `Dockry-*` tag does the same.

## Setup

### Permissions for desktop switching

macOS has no public API for desktops (Spaces), so Dockry presses the system's own
**Switch to Desktop N** shortcut for you. You need to do two things once, and the menu bar
menu tells you which one is still missing:

1. Turn on *Switch to Desktop 1, 2, …* in System Settings › Keyboard › Keyboard Shortcuts ›
   Mission Control. Each desktop must already exist in Mission Control.
2. Give Dockry Accessibility access in System Settings › Privacy & Security, so it can send
   the shortcut.

Profiles and the dock work without either of these.

### Fast User Switching

macOS has no public API for switching users, and the old `CGSession` tool has been removed.
Dockry calls the private login.framework function behind Fast User Switching
(`SACSwitchToUser`, given the account's name and UID). CI checks on every run that it still
takes the current session off the screen. It can't check that it lands on the chosen account
instead of the general login window, because that account would have to be logged in. If a
future macOS removes the function, Dockry opens the login window instead, which lists every
account.
Fast User Switching must be turned on: System Settings › Control Center › Fast User
Switching, or Users & Groups on older versions.

### Spotify

The widget reads what's playing from the notification Spotify broadcasts, which needs no
permission. Album art and the playback buttons use AppleScript, so the first time macOS asks
whether Dockry may control Spotify. If you decline, the widget still shows the song but
the buttons do nothing. You can change this later in System Settings › Privacy & Security ›
Automation. Pressing play while Spotify is closed opens it.

### If the system Dock stays hidden

Dockry restores the Dock when it quits normally or receives `SIGTERM`. If it crashes,
reopening Dockry and turning off **Hide macOS Dock** restores it. Or run:

```bash
defaults delete com.apple.dock autohide-delay; killall Dock
```

## Profiles file

Profiles live in `~/Library/Application Support/Dockry/profiles.json`. **Edit Profiles…**
opens the file, and **Reload Profiles** applies your changes. Only `name` is required:

```json
{
  "activeProfileName": "Work",
  "profiles": [
    {
      "name": "Work",
      "symbol": "briefcase.fill",
      "desktop": 1,
      "pinnedApps": ["com.apple.Safari", "com.apple.mail"],
      "widgets": ["clock", "date"]
    }
  ]
}
```

- `symbol` is an [SF Symbol](https://developer.apple.com/sf-symbols/) name.
- `pinnedApps` are bundle identifiers. To find one, run `osascript -e 'id of app "Safari"'`.
- `widgets` can include `clock`, `date`, `spotify` and `users`, shown in the order you list them.
- `desktop` can be 1 to 9. Leave it out to stay on the current desktop.

If the file can't be read, the menu says so and Dockry uses the default profiles without
saving over your file. Fix it and choose **Reload Profiles**. If you edit it in TextEdit,
turn off Edit › Substitutions › Smart Quotes first: curly quotes aren't valid JSON.

## Project layout

| Path | What's there |
|---|---|
| `Sources/DockryCore` | Profiles, the dock's layout rules, shortcut parsing. Plain Foundation, unit tested. |
| `Sources/Dockry` | The app: dock window and views, menu bar, hot keys, system Dock and desktop integration. |
| `App/Info.plist` | Bundle metadata used by `scripts/bundle.sh`. |
| `.github/workflows/macos.yml` | Builds, tests and takes the screenshots on a macOS runner. |
| `.github/workflows/release.yml` | Builds a universal Dockry.app and publishes it, as a disk image and a zip, as a GitHub release. |
