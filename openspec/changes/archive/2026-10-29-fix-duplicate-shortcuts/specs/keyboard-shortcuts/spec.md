# Spec Delta

## ADDED Requirements

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
