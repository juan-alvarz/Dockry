# Spec Delta

## ADDED Requirements

### Requirement: Renaming keeps a profile's apps and windows
Renaming a profile SHALL keep every open app and every window that belonged to it under the new name, whether or not it is the active profile. Apps and windows of other profiles SHALL not change profile.

#### Scenario: Rename a profile that isn't active
- **WHEN** Work is active, Music belongs to Chill, and the user renames Chill to Home
- **THEN** Music belongs to Home and still doesn't show in Work's dock

#### Scenario: Rename in window mode
- **WHEN** window mode is on, Zen has a window in Chill, and the user renames Chill to Home and switches to it
- **THEN** Zen's window comes back on screen
