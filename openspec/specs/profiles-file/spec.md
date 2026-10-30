# profiles-file Specification

## Purpose

Profiles are saved in a JSON file the user can read and edit by hand. This spec covers the file's location, format, lenient reading, backward compatibility, and how Dockry protects a file it can't read.

## Requirements

### Requirement: Location and format
Profiles SHALL be saved to `~/Library/Application Support/Dockry/profiles.json` as pretty-printed JSON with sorted keys, holding `activeProfileName` and a `profiles` array. Each save SHALL write the whole file atomically, creating the folder if needed.

#### Scenario: Saving after a change
- **WHEN** any profile change is made
- **THEN** the file is rewritten at once with the new profiles, and an interrupted write never leaves a half-written file

### Requirement: Dock items as strings
Each dock item SHALL be stored as one string: a bundle identifier for an app, `widget:<name>` for a widget, `folder:<path>` for a folder, `divider` and `running-apps`. Widget names are `clock`, `date`, `spotify`, `users`, `claude`, `weather` and `trash`.

#### Scenario: Round trip
- **WHEN** a profile with an app, a divider, the open apps' place, a widget and a folder is saved and read back
- **THEN** the items are the same, in the same order

### Requirement: Only the name is required
Reading a profile SHALL need only `name`. A missing `symbol` gets the default symbol, and missing options are off.

#### Scenario: Minimal profile
- **WHEN** the file has a profile with just `{"name": "Focus"}`
- **THEN** it loads as a profile named Focus with the defaults

### Requirement: Bad values drop only themselves
An unknown widget name SHALL drop only that item. An invalid `color` (not six hex digits, with or without `#`), `shortcut`, `opensAppsOnSwitch`, `wallpaper` or `freshApps` SHALL drop only that value. Colors SHALL be stored normalized as upper-case `#RRGGBB`.

#### Scenario: Typo in a widget
- **WHEN** a profile's items include `widget:clok`
- **THEN** the profile loads without that item and with all the others

#### Scenario: Lower-case color without hash
- **WHEN** a profile's color is `3563e9`
- **THEN** it loads as `#3563E9`

### Requirement: Older files keep loading
A profile without `items` but with `pinnedApps` and `widgets` SHALL load as its apps, a divider, the open apps' place, a divider, then its widgets.

#### Scenario: File from before items
- **WHEN** a profile has `"pinnedApps": ["com.apple.Safari"]` and `"widgets": ["clock"]`
- **THEN** its items are Safari, divider, open apps, divider, clock

### Requirement: Off options aren't written
Saving SHALL omit `opensAppsOnSwitch` and `freshApps` when they are off, and omit optional values that aren't set.

#### Scenario: Default options
- **WHEN** a profile with both options off is saved
- **THEN** neither key appears in its JSON

### Requirement: An unreadable file is never overwritten
If the file exists but can't be read or decoded, Dockry SHALL use the default profiles, report the error, and save no changes until the file is reloaded successfully. A missing file SHALL simply give the defaults.

#### Scenario: Invalid JSON
- **WHEN** profiles.json contains invalid JSON at launch
- **THEN** the default profiles are shown, the menu bar menu and Settings › Profiles say the file has an error and changes aren't saved, and the file is left untouched

#### Scenario: Fixing the file
- **WHEN** the user fixes the file and chooses Reload from File in Settings › Profiles
- **THEN** the file's profiles are loaded and changes are saved again

### Requirement: Editing by hand
Settings › Profiles SHALL offer Edit as JSON… (opens the file in TextEdit, creating it first if missing), Reload from File, and Show in Finder.

#### Scenario: Edit as JSON before any save
- **WHEN** the user chooses Edit as JSON… and no file exists yet
- **THEN** the current profiles are saved to the file and it opens in TextEdit
