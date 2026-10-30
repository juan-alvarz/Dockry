# system-dock Specification

## Purpose

Lets Dockry hide the macOS Dock while it runs, without ever leaving the user without a Dock afterwards.

## Requirements

### Requirement: Hiding the macOS Dock
With "Hide macOS Dock" on (from the menu bar menu or Settings › General), Dockry SHALL save the user's own Dock auto-hide settings, then turn on auto-hide with a delay long enough that the Dock never shows, and restart the Dock so it takes effect.

#### Scenario: Turn it on
- **WHEN** the user turns on Hide macOS Dock
- **THEN** the macOS Dock disappears and stays hidden even at the screen edge

### Requirement: Giving it back
Turning the option off, quitting Dockry normally, or Dockry receiving SIGTERM (logout, `killall`) SHALL put back exactly the saved values (removing keys that weren't set) and restart the Dock.

#### Scenario: Quit Dockry
- **WHEN** Dockry quits while hiding the macOS Dock
- **THEN** the Dock comes back with the user's own auto-hide settings

### Requirement: Surviving a crash
The saved values SHALL be kept until a restore succeeds. If Dockry starts while it had hidden the Dock, it SHALL not save its own values as the user's.

#### Scenario: Crash then reopen
- **WHEN** Dockry crashed while hiding the Dock, is reopened, and the user turns the option off
- **THEN** the user's settings from before Dockry hid the Dock are restored

### Requirement: Persisted choice
The option SHALL be remembered; when Dockry launches with it on, it SHALL hide the Dock again.

#### Scenario: Launch with the option on
- **WHEN** Dockry opens at login with Hide macOS Dock on
- **THEN** the macOS Dock is hidden

### Requirement: Docks use the freed space
While Dockry hides the macOS Dock, its docks SHALL use the space the macOS Dock had, following the Dock's restart for a few seconds while macOS updates the usable area.

#### Scenario: Bottom dock after hiding
- **WHEN** both docks are at the bottom and Dockry hides the macOS Dock
- **THEN** Dockry's dock moves down to the screen's bottom edge
