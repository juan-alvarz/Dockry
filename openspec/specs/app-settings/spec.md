# app-settings Specification

## Purpose

Dockry's Settings window and the preferences it keeps outside profiles.json: where Settings opens from, its tabs, the defaults of each preference, how they are remembered, and opening at login.

## Requirements

### Requirement: Opening Settings
Settings SHALL open from the menu bar menu (Settings…, Edit Profiles…), ⌘,, the dock's background menu (Dock Settings…), the profile button's menu (on that profile) and widgets that need setup (on that widget). Opening it SHALL bring Dockry forward and reuse one window.

#### Scenario: From the dock
- **WHEN** the user chooses Dock Settings… on the dock's background
- **THEN** the Settings window comes forward

### Requirement: Tabs
Settings SHALL have three tabs: General (version, sync with the Mac Dock, dock options, unpinned apps, keyboard, profiles options, windows, macOS Dock, startup), Profiles (list, editor and file actions) and Widgets.

#### Scenario: Version shown
- **WHEN** the user opens Settings › General
- **THEN** it shows the version of the running build

### Requirement: Defaults
Preferences SHALL default to: bottom position, 48-point icons, magnification off with an 80-point magnified size, hiding off, indicators and launch animation on, sync with the Mac Dock off, unpinned apps shown, Hide macOS Dock off, keep windows clear on, per-profile apps off, new app instance off, wallpaper animation on as Fade for 0.3 seconds, and no switcher shortcut.

#### Scenario: First launch
- **WHEN** Dockry runs for the first time
- **THEN** the dock is at the bottom with 48-point icons and no magnification

### Requirement: Remembered across launches
Every preference SHALL be saved as soon as it changes and restored at launch; out-of-range values SHALL be clamped (icon and magnified size to 16–128, wallpaper animation to 0.1–1 second).

#### Scenario: Restart
- **WHEN** the user moves the dock to the right and restarts Dockry
- **THEN** the dock is on the right

### Requirement: Settings carry over from the old identifier
On first launch under the bundle identifier `com.dockry.Dockry`, Dockry SHALL copy the preferences saved under its old identifier `io.github.juan-alvarz.Dockry`, if any.

#### Scenario: Upgrade from 0.0.7
- **WHEN** a user of 0.0.7 updates to a later version
- **THEN** their dock settings are the same as before

### Requirement: Open at login
Settings › General SHALL offer Open Dockry at login. If the system refuses, Settings SHALL show why and that Dockry needs to be in the Applications folder, and the toggle SHALL show the real state.

#### Scenario: Turn on from a build folder
- **WHEN** the user turns it on and macOS refuses
- **THEN** an error explains it and the toggle stays off

### Requirement: Profile editor
Settings › Profiles SHALL list profiles (with fresh badge and Active marker) with add, remove, duplicate and move up/down, and edit the selected profile's name, shortcut, symbol (from suggestions), color (suggestions, a color well or none), desktop, wallpaper, open-on-switch option, pinned apps (add, reorder, remove) and widgets (turn on or off, reorder). Remove SHALL be disabled when only one profile is left.

#### Scenario: Add apps
- **WHEN** the user clicks Add App… and picks two apps in Applications
- **THEN** both are pinned at the end of the profile's apps, skipping any already pinned

#### Scenario: Missing app
- **WHEN** a pinned app isn't installed
- **THEN** the editor shows its bundle identifier with a placeholder icon
