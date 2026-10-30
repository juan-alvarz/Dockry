# profile-switcher Specification

## Purpose

A ⌘Tab-style overlay for switching profiles from the keyboard, opened by a shortcut the user sets or from the menu bar menu. This spec covers how it opens, moves, picks and cancels.

## Requirements

### Requirement: Opening
The switcher SHALL open centered horizontally on the main screen, a little above the middle, with the profile after the active one selected (wrapping to the first). It SHALL take the keyboard without making the user's app inactive.

#### Scenario: Open from the menu
- **WHEN** the user chooses Profile Switcher in the menu bar menu while Work (first of two) is active
- **THEN** the switcher shows both profiles with the second selected

### Requirement: Hold to choose
When opened by its shortcut while the shortcut's modifiers are still held, pressing the shortcut again SHALL move to the next profile, and releasing the modifiers SHALL switch to the selected profile.

#### Scenario: Quick press flips profiles
- **WHEN** the user presses and releases the switcher's shortcut once
- **THEN** Dockry switches to the next profile

#### Scenario: Cycle while holding
- **WHEN** the user holds the modifiers and presses the key three times with three profiles
- **THEN** the selection wraps around, and letting go switches to the selected one

### Requirement: Staying open
If the modifiers are already up when it opens, or it opened from the menu, the switcher SHALL stay open until a choice or cancel: Left/Right arrows and Tab/Shift-Tab move, Return or Enter picks the selection, digits 1–9 pick that profile, and Esc or clicking elsewhere cancels.

#### Scenario: Pick by number
- **WHEN** the switcher is open and the user presses 3
- **THEN** Dockry switches to the third profile and the switcher closes

#### Scenario: Cancel
- **WHEN** the user presses Esc
- **THEN** the switcher closes and the active profile doesn't change

### Requirement: Tiles
Each profile SHALL show as a tile with its symbol, name, a fresh-apps badge if it has fresh apps, up to five of its pinned apps' icons, and "Active" for the active profile or its shortcut otherwise. A tile SHALL show a speaker when one of that profile's apps is playing sound.

#### Scenario: Profile playing sound
- **WHEN** profiles keep their own apps and an app of Chill is playing sound
- **THEN** Chill's tile shows a speaker
