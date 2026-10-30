# profiles Specification

## Purpose

Profiles are named contexts such as Work and Chill. Each holds its own dock contents, desktop, look and options, and exactly one is active at a time. This spec covers the rules every profile and the set of profiles always keep.

## Requirements

### Requirement: Profile contents
A profile SHALL have a unique name and MAY have a symbol (an SF Symbol name), an ordered list of dock items, a desktop number from 1 to 9, a button color, a keyboard shortcut, a wallpaper path, an "open its apps when switching" option and a "fresh apps" option. Only the name is required.

#### Scenario: Profile with only a name
- **WHEN** a profile is created with only a name
- **THEN** it gets the default symbol `square.grid.2x2.fill`, no desktop, no color, no shortcut, no wallpaper, both options off, and a dock holding the place for open apps between two dividers

### Requirement: Dock items of a profile
A profile's dock items SHALL be an ordered list of pinned apps (by bundle identifier), widgets, folders (by path), dividers and exactly one place for open apps that aren't pinned. Each app, widget and folder SHALL appear at most once; dividers MAY repeat.

#### Scenario: Duplicates are dropped
- **WHEN** a profile's items are set to a list with the same app twice
- **THEN** only the first occurrence is kept

#### Scenario: Missing place for open apps
- **WHEN** a profile's items are set without the place for open apps
- **THEN** it is inserted right after the last pinned app, or first if there are no apps

#### Scenario: Several dividers
- **WHEN** a profile's items contain two dividers
- **THEN** both are kept

### Requirement: Editing pinned apps and widgets keeps the layout
Replacing a profile's list of pinned apps (or of widgets) SHALL leave every other item where it is: removed ones go, kept ones take the old slots in their new order, and new ones go after the last slot (or first for apps, last for widgets, when there were none).

#### Scenario: Reordering apps leaves widgets in place
- **WHEN** the apps of a profile with items `[A, B, divider, open apps, clock]` are set to `[B, A]`
- **THEN** the items become `[B, A, divider, open apps, clock]`

#### Scenario: Adding a widget
- **WHEN** a widget is added to a profile that already has widgets
- **THEN** it goes right after the last existing widget

### Requirement: Inserting and removing items
Inserting an item that the profile already has SHALL move it to the new place instead of adding a copy, except for dividers. Removing an item SHALL be refused for the place for open apps.

#### Scenario: Insert an existing widget
- **WHEN** a widget already in the dock is inserted at another position
- **THEN** it moves there and the dock still has it once

#### Scenario: Remove the place for open apps
- **WHEN** removing the place for open apps is requested
- **THEN** nothing changes

### Requirement: At least one profile, one active
The set of profiles SHALL always hold at least one profile with unique names, and the active profile name SHALL always name one of them.

#### Scenario: No profiles given
- **WHEN** the profiles are loaded from an empty list
- **THEN** the default profiles are used

#### Scenario: Unknown active name
- **WHEN** the active name doesn't match any profile
- **THEN** the first profile is active

#### Scenario: Duplicate names
- **WHEN** two profiles have the same name
- **THEN** only the first is kept

### Requirement: Default profiles
Without saved profiles, Dockry SHALL start with two profiles: Work (briefcase symbol, blue `#3563E9`, desktop 1, Finder, Safari, Mail, Calendar, Notes and Terminal, with the clock, calendar, Claude usage, weather and users widgets) and Chill (cup symbol, orange `#F08A4B`, desktop 2, Finder, Music, Photos, Messages and TV, with the Spotify, clock and users widgets). Work is active.

#### Scenario: First launch
- **WHEN** Dockry starts and has no profiles file
- **THEN** the Work and Chill profiles exist and Work is active

### Requirement: Adding profiles
Adding a profile SHALL give it the requested name, or that name followed by the first free number (" 2", " 3"…) if it's taken. A new profile is "New Profile", or "Fresh Profile" when it has fresh apps, and it is added at the end.

#### Scenario: Name already taken
- **WHEN** a profile is added while "New Profile" and "New Profile 2" exist
- **THEN** it is named "New Profile 3"

### Requirement: Duplicating profiles
Duplicating a profile SHALL insert a copy right after it, named "<name> Copy" (then "<name> Copy 2"…), with everything the original has except its keyboard shortcut.

#### Scenario: Duplicate keeps settings but not the shortcut
- **WHEN** a profile with a shortcut and a wallpaper is duplicated
- **THEN** the copy has the wallpaper and no shortcut, and sits right after the original

### Requirement: Renaming profiles
A rename SHALL trim surrounding spaces and SHALL be ignored when the result is empty or another profile's name; other changes made together with it still apply. Renaming the active profile keeps it active.

#### Scenario: Rename to a taken name
- **WHEN** a profile is renamed to another profile's name and its color is changed at the same time
- **THEN** the name stays as it was and the color changes

#### Scenario: Rename the active profile
- **WHEN** the active profile is renamed
- **THEN** it stays active under the new name

### Requirement: Removing and reordering profiles
Removing the only profile SHALL be refused. Removing the active profile SHALL activate the first remaining one. Profiles MAY be moved up or down in the list; moves past either end stop at the end.

#### Scenario: Remove the active profile
- **WHEN** the active profile is removed while two others exist
- **THEN** the first remaining profile becomes active

#### Scenario: Remove the last profile
- **WHEN** removing the only profile is requested
- **THEN** it stays

### Requirement: Pinning from the dock
Pinning an app SHALL add it after the active profile's last pinned app unless it is already pinned. Unpinning SHALL remove it from the active profile only.

#### Scenario: Pin an app twice
- **WHEN** an app that's already pinned is pinned again
- **THEN** the profile still has it once, in its old place
