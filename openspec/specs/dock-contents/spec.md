# dock-contents Specification

## Purpose

What the dock shows and in what order: the profile button, then the active profile's pinned apps, open apps, widgets, folders and dividers, and how the user rearranges, adds and removes them from the dock itself.

## Requirements

### Requirement: Order of the dock
The dock SHALL show the profile button first, a fixed divider, then the active profile's items in their saved order. At the place for open apps it SHALL show running regular apps that aren't pinned, in launch order, unless Settings turns that off.

#### Scenario: Unpinned app opens
- **WHEN** the user opens an app that isn't pinned in the active profile
- **THEN** it appears at the place for open apps, after any other unpinned open apps

#### Scenario: Hide unpinned apps
- **WHEN** "Show open apps that aren't in the profile" is off
- **THEN** only pinned apps, widgets, folders and dividers show

### Requirement: Which apps count as open
Open apps SHALL be the regular apps (those that would show in the macOS Dock), not agents or background processes, including apps that become regular some time after launching. An app without a bundle identifier SHALL be known by its path.

#### Scenario: App that turns regular late
- **WHEN** an app launches in the background and shows its first window later
- **THEN** it appears in the dock once it does

### Requirement: Missing apps and empty dividers
A pinned app that isn't installed (and isn't running) SHALL be left out. Dividers SHALL show where the user put them, including at either end or next to another divider. A divider SHALL be left out only when things that aren't shown (an empty group of open apps, a missing app) are all that separate it from an end or from another shown divider.

#### Scenario: Uninstalled app
- **WHEN** a profile pins an app that was deleted
- **THEN** the dock skips it and keeps it in the profile

#### Scenario: Two dividers in a row
- **WHEN** everything between two dividers is hidden
- **THEN** only one divider shows

#### Scenario: Divider added after an app
- **WHEN** the user right-clicks a pinned app followed by open apps and chooses Add Divider
- **THEN** a divider appears right after that app

#### Scenario: Divider at the end
- **WHEN** the user chooses Add Divider on the dock's background
- **THEN** a divider appears at the end of the dock

### Requirement: Running indicators
A running app SHALL show a dot on the screen-edge side when indicators are on. An app with minimized windows SHALL show a yellow dot next to it, when indicators are on and Accessibility access is granted.

#### Scenario: Minimized window
- **WHEN** an app has a window minimized into the macOS Dock
- **THEN** its icon shows a yellow dot beside the running dot

### Requirement: Hover labels and window lists
Hovering an app or folder SHALL show its name next to it, on the side facing the middle of the screen. Hovering an app with minimized windows SHALL instead list its windows (up to eight, minimized ones marked); the pointer can move onto the list, and clicking a window brings it back and to the front.

#### Scenario: Restore a minimized window
- **WHEN** the user hovers an app with a minimized window and clicks that window in the list
- **THEN** the window comes out of the macOS Dock and to the front

### Requirement: Drag to rearrange
Dragging an app, widget, folder or divider along the dock SHALL move it, with the other items sliding to show where it will land; letting go saves the new order to the active profile. Dragging an open app that isn't pinned SHALL pin it where it lands. The profile button and the divider after it SHALL not move.

#### Scenario: Pin by dragging
- **WHEN** the user drags an unpinned open app between two pinned apps
- **THEN** it is pinned there

#### Scenario: Profile changes mid-drag
- **WHEN** the active profile changes while an item is being dragged
- **THEN** letting go doesn't change any profile

#### Scenario: Releasing a drag
- **WHEN** the user lets go of a dragged app
- **THEN** the app doesn't also open

### Requirement: Drop from Finder
Dropping folders or apps from Finder onto the dock SHALL add them where the dock opened a gap for them: apps are pinned, folders added as stacks. Other files SHALL be refused.

#### Scenario: Drop an app
- **WHEN** the user drops Xcode.app from Finder between two pinned apps
- **THEN** Xcode is pinned there in the active profile

#### Scenario: Drop a document
- **WHEN** the user drags a PDF over the dock
- **THEN** the dock opens no gap and the drop is refused

### Requirement: Right-click menus
Right-clicking a pinned app SHALL offer Remove from <profile>, Show in Finder and, if it's running, Quit; an unpinned app offers Keep in <profile> instead of Remove. A widget offers Remove <widget> from <profile>; a divider (not the fixed one) offers Remove Divider; a folder offers Remove from <profile> and Open in Finder. Every item's menu SHALL also offer Add Divider, Add Folder… and Add Widget, which add right after it.

#### Scenario: Add a widget after an app
- **WHEN** the user right-clicks Safari and chooses Add Widget › Weather
- **THEN** the weather widget is added right after Safari in the active profile

#### Scenario: Only missing widgets are offered
- **WHEN** the active profile already has the clock
- **THEN** Add Widget doesn't list Clock
