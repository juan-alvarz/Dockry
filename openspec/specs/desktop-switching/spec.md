# desktop-switching Specification

## Purpose

Jumps to a profile's macOS desktop (Space) when switching to it. macOS has no public API for Spaces, so Dockry presses the system's own "Switch to Desktop N" shortcut, which needs that shortcut turned on and Accessibility access.

## Requirements

### Requirement: Uses the system shortcut
To switch to desktop N (1–9), Dockry SHALL read the user's "Switch to Desktop N" shortcut from the system and post that key press, so the normal switching animation plays. It SHALL do nothing when the shortcut is off or Accessibility access is missing.

#### Scenario: Shortcut changed by the user
- **WHEN** the user set "Switch to Desktop 2" to ⌥2 and switches to a profile on desktop 2
- **THEN** Dockry posts ⌥2 and macOS moves to desktop 2

#### Scenario: Shortcut off
- **WHEN** "Switch to Desktop 2" is off and the user switches to a profile on desktop 2
- **THEN** the profile becomes active and the desktop doesn't change

### Requirement: Says what's missing
The menu bar menu SHALL show one item for the first profile desktop Dockry can't switch to yet: Allow Desktop Switching… when Accessibility access is missing (it adds Dockry to the list and opens it), or Turn On "Switch to Desktop N" Shortcut… (opens Keyboard settings) when the shortcut is off. With nothing missing, no item SHALL show.

#### Scenario: Accessibility missing
- **WHEN** a profile has a desktop and Dockry has no Accessibility access
- **THEN** the menu shows Allow Desktop Switching…

### Requirement: Optional
Profiles and the dock SHALL work without desktop switching set up.

#### Scenario: Nothing set up
- **WHEN** neither the shortcuts nor Accessibility are set up
- **THEN** switching profiles still swaps the dock, apps and wallpaper
