# Spec Delta

## ADDED Requirements

### Requirement: Saved ownership applies only to the same process
When Dockry starts, an already running app SHALL get the profile saved for it only if it is the same process that was saved (same process id and launch time); any other app SHALL join the active profile. A saved window's profile SHALL apply only to a window of the process it was saved for.

#### Scenario: Dockry restarts
- **WHEN** Music belongs to Chill, Dockry quits and reopens while Music keeps running
- **THEN** Music still belongs to Chill

#### Scenario: Mac restarts
- **WHEN** the Mac restarts and a different app gets the process id Music had
- **THEN** that app belongs to the active profile, not to Chill
