# Changelog

The first `## <version>` heading below is Dockry's version: `scripts/bundle.sh` stamps it into
the app, and the Release workflow, started by hand, publishes that version as `Dockry-<version>`
with its notes. Each version is released once: to release, add a new heading on top with what
changed. A heading that isn't a version, like `## Unreleased`, is skipped.

A version's section is Markdown: `###` subsections (What's new, Fixes, Updating from …) and
bullets that start with a **bold lead-in**. Wrap lines freely; the release notes join them
back (`scripts/version.sh --notes`), so a new line only starts at a blank line, a bullet or
a heading.

## 0.2.0

### What's new

- **Apple Music widget.** What's playing in the Music app, with previous, play/pause and
  next. Click the song for a player with progress, volume, shuffle, repeat and a search of
  your library that plays songs without bringing Music to the front.
- **Trash widget.** The Trash, like the macOS Dock's: drop files on it to move them to the
  Trash, click it to open the Trash, right-click it to empty it (it asks first).
- **Widgets grow with magnification**, like app icons, and a wide one grows fully wherever
  the pointer is along it.
- **Celsius or Fahrenheit** for the weather widget, in Settings › Widgets › Weather.
  Celsius is the default.
- **A quieter first launch.** A new install starts with one profile, Default, with Finder,
  so Dockry asks for no permissions until you add something that needs them.
- **Dividers stay where you add them**, even at an end of the dock or next to another
  divider.

### Fixes

- **Renaming a profile** keeps its open apps and windows with it, and renames once you're
  done typing instead of on every key.
- **Window managers like Rectangle** can no longer move or resize the dock.
- **Shortcuts:** Settings won't give two of Dockry's actions the same shortcut, and when two
  already share one it says so instead of blaming another app.
- **After the Mac restarts,** apps no longer end up in a profile that belonged to another app.

### Updating from 0.1.1

Quit Dockry from its menu bar item, drag the new Dockry into Applications and replace the
old one. Your profiles and settings are kept. Apps that are already open join the active
profile once, since Dockry now tells apps apart by when they launched.

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
