# Spec Delta

## MODIFIED Requirements

### Requirement: Units
Settings › Widgets › Weather SHALL offer Temperature: System, Celsius or Fahrenheit, remembered across launches. System (the default) SHALL follow the Temperature setting in System Settings › General › Language & Region, or the region's measurement system when it isn't set. Changing the choice SHALL refresh the widget at once.

#### Scenario: Fahrenheit
- **WHEN** the choice is System and the Mac's Temperature setting is Fahrenheit
- **THEN** the widget asks for and shows Fahrenheit

#### Scenario: Choose Celsius on a Fahrenheit Mac
- **WHEN** the Mac's Temperature setting is Fahrenheit and the user picks Celsius in Settings › Widgets › Weather
- **THEN** the widget shows Celsius right away and keeps doing so after Dockry restarts
