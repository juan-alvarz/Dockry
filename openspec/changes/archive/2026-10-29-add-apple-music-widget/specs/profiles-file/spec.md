# Spec Delta

## MODIFIED Requirements

### Requirement: Dock items as strings
Each dock item SHALL be stored as one string: a bundle identifier for an app, `widget:<name>` for a widget, `folder:<path>` for a folder, `divider` and `running-apps`. Widget names are `clock`, `date`, `spotify`, `music`, `users`, `claude`, `weather` and `trash`.

#### Scenario: Round trip
- **WHEN** a profile with an app, a divider, the open apps' place, a widget and a folder is saved and read back
- **THEN** the items are the same, in the same order
