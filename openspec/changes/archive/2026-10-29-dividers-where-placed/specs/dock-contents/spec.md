# Spec Delta

## MODIFIED Requirements

### Requirement: Missing apps and empty dividers
A pinned app that isn't installed (and isn't running) SHALL be left out. Dividers SHALL show where the user put them, including at either end or next to another divider. A divider SHALL be left out only when things that aren't shown (an empty group of open apps, a missing app) are all that separate it from an end or from another shown divider.

#### Scenario: Uninstalled app
- **WHEN** a profile pins an app that was deleted
- **THEN** the dock skips it and keeps it in the profile

#### Scenario: Two dividers in a row
- **WHEN** everything between two dividers is hidden
- **THEN** only one divider shows

#### Scenario: Divider added after an app
- **WHEN** the user right-clicks a pinned app followed by open apps and chooses Add Divider
- **THEN** a divider appears right after that app

#### Scenario: Divider at the end
- **WHEN** the user chooses Add Divider on the dock's background
- **THEN** a divider appears at the end of the dock

## REMOVED Requirements

### Requirement: Add Divider only where it shows
**Reason**: It kept the user from placing dividers, and was greyed out even where a divider would show.
**Migration**: Add Divider is always enabled; dividers show where they're added (see "Missing apps and empty dividers").
