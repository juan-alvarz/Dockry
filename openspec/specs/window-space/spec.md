# window-space Specification

## Purpose

Keeps other apps' windows out of the dock's space, as the macOS Dock does. macOS only lets its own Dock change the area it gives windows, so Dockry moves or shrinks windows that end up behind the dock.

## Requirements

### Requirement: On by default, needs Accessibility
"Keep windows out of the dock's space" SHALL be on by default and SHALL need Accessibility access; while access is missing, Settings SHALL say so and offer Allow…, which opens the Accessibility list. Dockry SHALL notice access being granted without restarting.

#### Scenario: Access granted later
- **WHEN** the user turns on Dockry in Privacy & Security › Accessibility while it runs
- **THEN** windows start being kept clear within a few seconds

### Requirement: No space while hiding
While the dock hides automatically, or the setting is off, Dockry SHALL keep no space and move no window.

#### Scenario: Autohide on
- **WHEN** automatic hiding is on and a window is zoomed
- **THEN** the window fills the screen down to the bottom

### Requirement: The reserved strip
On each screen with a dock, the reserved strip SHALL be the dock's thickness plus its gap from the screen edge and the same gap again, against the dock's edge. Magnified icons MAY still go over windows.

#### Scenario: Zoomed window
- **WHEN** a window is zoomed on a screen with a bottom dock
- **THEN** it is cut to end just above the dock's strip

### Requirement: Fitting a window
A window that overlaps the strip SHALL move out of it at its size if it fits in the space left, or be cut to fill that space if it doesn't. Its other sides SHALL be left alone. Panels, sheets, minimized windows, full-screen windows and windows parked off screen SHALL be left alone.

#### Scenario: Window pushed partly off screen
- **WHEN** a window extends past the right edge and its bottom is behind a bottom dock
- **THEN** it moves up and still extends past the right edge

### Requirement: Wait for the drag to end
A window that changes while the mouse button is down SHALL be fitted only once the button is up. A window Dockry just moved SHALL not be moved again within a second, so an app that refuses a size isn't fought.

#### Scenario: Drag a window behind the dock
- **WHEN** the user drags a window down behind the dock and lets go
- **THEN** it moves back out after the mouse button is up, not during the drag

### Requirement: Refit on dock changes
When the dock's strip changes (size, position, screens, hiding the macOS Dock), every watched window SHALL be fitted again.

#### Scenario: Bigger dock
- **WHEN** the user makes the dock larger
- **THEN** windows that are now behind it move out
