# Spec Delta

## MODIFIED Requirements

### Requirement: Default profiles
Without saved profiles, Dockry SHALL start with exactly one profile, named Default, with the house symbol (`house.fill`) and Finder pinned, followed by the place for open apps. It SHALL have no widgets, folders, desktop, color, shortcut or wallpaper, and both options off, so a first launch asks for no permissions. It is active.

#### Scenario: First launch
- **WHEN** Dockry starts and has no profiles file
- **THEN** the only profile is Default, it is active, and its dock shows the profile button, Finder and any open apps

#### Scenario: No permission prompts on first launch
- **WHEN** Dockry starts for the first time
- **THEN** no widget asks for Keychain, Location or Automation access
