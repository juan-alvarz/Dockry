## MODIFIED Requirements

### Requirement: Always kept apart
A fresh profile's own copies SHALL never show in another profile, nor other profiles' apps in it, whether or not "Give each profile its own windows" is on: their windows are parked whenever the other side is active. Bringing forward an app that belongs to a fresh profile, or a shared app while a fresh profile is active, SHALL switch to the app's profile.

#### Scenario: Switch away from a fresh profile
- **WHEN** the user switches from a fresh profile to Work
- **THEN** the fresh profile's copies' windows go off screen and Work's come back

#### Scenario: ⌘Tab to a fresh profile's copy
- **WHEN** Work is active and the user ⌘Tabs to a fresh profile's copy of Chrome
- **THEN** Dockry switches to the fresh profile
