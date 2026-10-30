# menu-bar Specification

## Purpose

Dockry has no icon in the Dock and no menus of its own; its menu bar item is where the user switches profiles, reaches its settings and quits it.

## Requirements

### Requirement: No Dock icon
Dockry SHALL run as a menu bar app with no icon in the macOS Dock and no app menus, while still giving its Settings window the standard ⌘, ⌘W, ⌘Q and Edit shortcuts (cut, copy, paste, select all, undo, redo).

#### Scenario: Paste in Settings
- **WHEN** the user presses ⌘V in a text field in Settings
- **THEN** the text is pasted

### Requirement: Menu bar icon
The menu bar item SHALL show the active profile's symbol.

#### Scenario: Switch profile
- **WHEN** the active profile changes to Chill
- **THEN** the menu bar icon becomes Chill's cup

### Requirement: Menu contents
The menu SHALL be built fresh each time it opens and list, in order: a Profiles section with every profile (symbol, check on the active one, its shortcut, fresh-apps and playing-sound badges) and Profile Switcher; Switch User, Hide macOS Dock (checked when on) and a desktop-switching hint when one is needed; a warning when profiles.json has an error, Edit Profiles… and Settings…; and Quit Dockry.

#### Scenario: Broken profiles file
- **WHEN** profiles.json couldn't be read
- **THEN** the menu shows a warning that changes aren't saved until it's fixed, which opens Settings › Profiles

#### Scenario: Toggle the macOS Dock
- **WHEN** the user chooses Hide macOS Dock while it's unchecked
- **THEN** the macOS Dock is hidden and the item shows a check next time

### Requirement: Switch User submenu
Switch User SHALL list the Mac's other accounts by full name, then Login Window…

#### Scenario: Another account
- **WHEN** the Mac has another account named Alex Rivera
- **THEN** Switch User lists Alex Rivera, and choosing it switches to that account
