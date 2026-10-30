# profile-switching Specification

## Purpose

Switching makes another profile active, from any of several places, and brings along what belongs to it: its dock contents, desktop, wallpaper, apps, and optionally its pinned apps opening. This spec covers the ways to switch and what follows a switch.

## Requirements

### Requirement: Ways to switch
The user SHALL be able to switch profiles from the menu bar menu, from the profile button at the start of the dock (which shows a menu of profiles), from the profile switcher, from a profile's own keyboard shortcut, from Settings › Profiles (Make Active), and with the URL `dockry://profile/<name>`.

#### Scenario: Switch from the dock
- **WHEN** the user clicks the profile button and picks Chill
- **THEN** Chill becomes active

#### Scenario: Switch from a script
- **WHEN** `open dockry://profile/Work` runs
- **THEN** Work becomes active

#### Scenario: Unknown profile name
- **WHEN** a switch is requested to a profile name that doesn't exist
- **THEN** the active profile stays as it was

### Requirement: The dock follows the active profile
Every dock SHALL show the active profile's items as soon as it becomes active, and the menu bar item SHALL show the active profile's symbol.

#### Scenario: Switching swaps the dock
- **WHEN** the active profile changes from Work to Chill
- **THEN** the docks on every screen show Chill's apps and widgets, and the menu bar icon becomes Chill's symbol

### Requirement: Jump to the profile's desktop
Switching through Dockry's menus, button, switcher, shortcuts or URL to a profile with a desktop number SHALL switch to that macOS desktop. A profile without one SHALL stay on the current desktop.

#### Scenario: Profile with a desktop
- **WHEN** the user switches to a profile set to Desktop 2 and desktop switching is ready
- **THEN** macOS moves to desktop 2

#### Scenario: Make Active in Settings
- **WHEN** the user clicks Make Active in Settings › Profiles
- **THEN** the profile becomes active without switching desktops

### Requirement: Open the profile's apps on switch
A profile with "open its apps when switching" on SHALL open each of its pinned apps that isn't running, in the background so the app in front keeps the keyboard, once the desktop switch has finished (or within about a second if no switch happens). Apps that aren't installed are skipped.

#### Scenario: Switch to a profile that opens its apps
- **WHEN** the user switches to such a profile and two of its apps aren't running
- **THEN** both open without coming to the front, on the profile's desktop

#### Scenario: Renaming isn't switching
- **WHEN** the active profile is renamed
- **THEN** no apps open and the profile's apps aren't shown or hidden again

### Requirement: Profile menu from the dock
The profile button's menu SHALL list every profile with its symbol, a check on the active one and its shortcut, and end with an item that opens the active profile in Settings › Profiles.

#### Scenario: Edit the active profile
- **WHEN** the user chooses Edit "Work" Profile… from the profile button's menu
- **THEN** Settings opens on the Profiles tab with Work selected

### Requirement: Profile button look
The profile button SHALL show the profile's symbol on its color (with white or dark text, whichever reads better), or on a plain gray tile without a color. On a bottom dock with icons of at least 36 points it SHALL also show the profile's name.

#### Scenario: Light color
- **WHEN** a profile's color is a light yellow
- **THEN** its button's symbol and name are dark
