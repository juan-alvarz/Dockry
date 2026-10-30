# Spec Delta

## ADDED Requirements

### Requirement: Add Divider only where it shows
Add Divider SHALL be enabled in a right-click menu only when a divider inserted there would show in the dock; otherwise it SHALL be greyed out. A divider added through it SHALL always appear.

#### Scenario: Next to an existing divider
- **WHEN** the profile is Finder, a divider and the open apps, and the user right-clicks Finder
- **THEN** Add Divider is greyed out

#### Scenario: Between open apps and a widget
- **WHEN** the weather widget comes right after the open apps and the user right-clicks an open app
- **THEN** Add Divider is enabled and adds a divider between the open apps and the weather widget
