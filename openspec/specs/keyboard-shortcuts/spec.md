# keyboard-shortcuts Specification

## Purpose

Global keyboard shortcuts the user sets for the profile switcher and for each profile. Dockry sets none of its own, so it never clashes with other apps. This spec covers recording, validity, registration and conflicts.

## Requirements

### Requirement: No shortcuts by default
Dockry SHALL register no global shortcut until the user records one.

#### Scenario: Fresh install
- **WHEN** Dockry runs with no shortcuts set
- **THEN** no key combination anywhere is taken by Dockry

### Requirement: Where shortcuts are set
The user SHALL be able to set a shortcut for the profile switcher in Settings › General › Keyboard, and one per profile in Settings › Profiles. A profile's shortcut switches to it; the switcher's opens the switcher.

#### Scenario: Profile shortcut
- **WHEN** Chill's shortcut is ⌃⌥2 and the user presses ⌃⌥2 in any app
- **THEN** Dockry switches to Chill

### Requirement: Recording
Clicking the recorder SHALL start recording; the next key press with modifiers becomes the shortcut. Esc cancels, Delete or Forward Delete clears it, and a clear button removes a set shortcut. While recording, Dockry's existing shortcuts SHALL be suspended so pressing one records it instead of running it.

#### Scenario: Record a shortcut Dockry already uses
- **WHEN** the user records ⌃⌥Space for a profile while it's the switcher's shortcut
- **THEN** the recorder takes ⌃⌥Space instead of opening the switcher

### Requirement: Needs a real modifier
A shortcut SHALL include ⌃, ⌥ or ⌘; with only ⇧ or no modifier it SHALL be refused with a hint to use one of them.

#### Scenario: Shift only
- **WHEN** the user presses ⇧A while recording
- **THEN** nothing is recorded and the recorder says to use ⌃, ⌥ or ⌘

### Requirement: Shortcuts taken by other apps
A shortcut the system won't register SHALL be shown in Settings as already used by another app, and the rest of Dockry's shortcuts SHALL still work.

#### Scenario: Conflict
- **WHEN** the user records a shortcut another app has registered
- **THEN** Settings says another app already uses it

### Requirement: Display
Shortcuts SHALL be shown as modifier symbols in ⌃⌥⇧⌘ order followed by the key as the keyboard labels it, such as ⌃⌥Space or ⌃⌥1.

#### Scenario: Display string
- **WHEN** a shortcut is ⌘⌃ with the 1 key
- **THEN** it reads ⌃⌘1

### Requirement: One action per shortcut
Each key combination SHALL belong to at most one of Dockry's shortcuts. Recording a combination another Dockry shortcut has SHALL be refused with a hint naming it (a profile or the profile switcher). When a combination is set twice anyway, only the first SHALL be registered, and Settings SHALL say it clashes with another Dockry shortcut rather than with another app.

#### Scenario: Record a profile's shortcut for another profile
- **WHEN** Work's shortcut is ⌃⌥1 and the user records ⌃⌥1 for Chill
- **THEN** nothing is recorded and the recorder says Work already uses it

#### Scenario: Duplicate from a hand-edited file
- **WHEN** profiles.json gives Work and Chill the same shortcut
- **THEN** the shortcut switches to Work, and Settings says it's also used by another Dockry shortcut

#### Scenario: Same keys, different label
- **WHEN** two shortcuts have the same key code and modifiers but were recorded with different key labels
- **THEN** they count as the same shortcut
