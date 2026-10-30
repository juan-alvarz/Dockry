# Spec Delta

## ADDED Requirements

### Requirement: Other apps can't move the dock
Window managers and other apps SHALL not be able to move, resize, zoom or minimize the dock, even while Dockry is the active app. If the dock is moved by any means, it SHALL return to its place at once. The dock SHALL stay readable by assistive apps.

#### Scenario: Maximize shortcut while a dock popover is open
- **WHEN** a dock popover is open and the user presses Rectangle's maximize shortcut
- **THEN** the dock stays where it was

#### Scenario: Moved through Accessibility
- **WHEN** an app sets the dock window's position through Accessibility
- **THEN** the dock is back in its place right away
