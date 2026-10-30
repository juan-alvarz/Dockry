# Changelog

The first `## <version>` heading below is Dockry's version: `scripts/bundle.sh` stamps it into
the app, and the Release workflow, started by hand, publishes that version as `Dockry-<version>`
with its notes. Each version is released once: to release, add a new heading on top with what
changed. A heading that isn't a version, like `## Unreleased`, is skipped.

## Unreleased

- Apple Music widget: what's playing in Music with its controls, and a player that searches your library.
- Dividers show where you add them, even at an end or next to another divider.
- Trash widget: drop files on it to delete them, click to open the Trash, right-click to empty it.
- Widgets grow with magnification, like app icons.
- The weather widget shows Celsius, or Fahrenheit if you pick it in Settings › Widgets › Weather.
- A new install starts with one profile, Default, with Finder, instead of Work and Chill,
  so Dockry doesn't ask for any permissions until you add something that needs them.
- Renaming a profile keeps its open apps and windows, and happens once you're done typing
  the name instead of on every key.
- Window managers like Rectangle can no longer move or resize the dock.
- Settings won't give two of Dockry's actions the same shortcut, and says when two already
  share one instead of blaming another app.
- After the Mac restarts, apps no longer land in a profile that belonged to another app.

## 0.1.1

- Weather widget: current conditions with today's high and low from Open-Meteo, for your town
  from Location Services. Temperatures follow your Language & Region setting; click it for the
  Weather app.
- Removing a fresh profile asks first and moves its app data to the Trash, unless you check
  "I want to preserve the data".
- In window mode, switching profiles hides apps with no window in the profile, so Mission
  Control doesn't show their parked windows.

## 0.1.0

- The version Dockry shows in Settings now always matches the build: it comes from this
  changelog, which also gives each release its notes.

## 0.0.9

- Profiles get their own wallpapers (switched with a fade you can style or turn off), can be
  cloned and keep their own open apps and windows, like Mac desktops.
- Fresh profiles, chosen when you create one, start with their own copies of apps and their data,
  and hide every other app.
- Optionally open a new copy of an app that's open in another profile.
- Edit the active profile from the dock's profile menu.
- Drop folders and apps from Finder onto the dock; folders and minimized windows show in the dock.
- The bundle identifier is now `com.dockry.Dockry`; settings carry over.
- Allow… opens the Accessibility list, since macOS prompts only once.

## 0.0.7

- Arrange the dock freely: drag apps, widgets and dividers, and add them from the right-click menu.
- Claude usage widget.
- Every widget describes itself, with a Widgets settings page.
- Set Dockry's keyboard shortcuts yourself instead of it taking ⌃⌥1–9 and ⌃⌥Space.
- Keep windows out of the dock's space, like the macOS Dock.
- Quit apps through their own Quit menu item, without a prompt per app.
- Every open app shows in the dock, including ones that became regular apps late.
- Fixes: a crash when an app switches between background and regular, the resize cursor getting
  stuck after using the separator.

## 0.0.6

- Spotify progress, search on demand, side-dock widgets, resize cursor and profile colors.

## 0.0.5

- Works like the macOS Dock: positions, every screen, magnification and settings.
- App icon.
- Releases come as a disk image too.

## 0.0.1

- First release: a floating dock with profiles, a profile switcher, a menu bar menu, hot keys,
  a Spotify widget and Fast User Switching.
