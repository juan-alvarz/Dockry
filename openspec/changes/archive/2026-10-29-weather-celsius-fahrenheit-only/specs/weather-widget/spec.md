# Spec Delta

## MODIFIED Requirements

### Requirement: Units
Settings › Widgets › Weather SHALL offer Temperature: Celsius or Fahrenheit, Celsius by default, remembered across launches. The widget SHALL use that choice only, whatever macOS's or the Weather app's settings are. Changing it SHALL refresh the widget at once.

#### Scenario: Fahrenheit
- **WHEN** the user picks Fahrenheit
- **THEN** the widget shows Fahrenheit right away and keeps doing so after Dockry restarts

#### Scenario: Choose Celsius on a Fahrenheit Mac
- **WHEN** macOS or the Weather app is set to Fahrenheit and Dockry's choice is Celsius
- **THEN** the widget shows Celsius

#### Scenario: Default
- **WHEN** Dockry runs with no unit chosen, or with a choice saved by an older version
- **THEN** the widget shows Celsius and Settings shows Celsius selected
