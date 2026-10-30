# Spec Delta

## ADDED Requirements

### Requirement: Renaming happens when editing ends
The profile editor's name field SHALL rename the profile once, when the user presses Return, leaves the field, or selects another profile, and not while typing. An empty name or another profile's name SHALL put the field back to the current name.

#### Scenario: Typing a new name
- **WHEN** the user types "Home" over "Chill" and presses Return
- **THEN** the profile is renamed once, from Chill to Home, and profiles.json is saved once

#### Scenario: Taken name
- **WHEN** the user types "Work" for another profile and presses Return
- **THEN** the field shows that profile's name again
