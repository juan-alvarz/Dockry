# Proposal

## Why

The weather widget always follows the Mac's Temperature setting; there's no way to choose
Celsius or Fahrenheit for Dockry itself, and the widget has no settings of its own.

## What Changes

- Settings › Widgets › Weather gets a Temperature choice: System (default, as today),
  Celsius or Fahrenheit.
- Changing it refreshes the widget at once in the new unit.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `weather-widget`: "Units" now follows Dockry's own choice first, then the system.

## Impact

- `Sources/DockryCore/Weather.swift` (`TemperatureUnit`) and tests.
- `Sources/Dockry/Widgets/Weather/WeatherMonitor.swift`, a new `WeatherSettings.swift`,
  `WeatherWidget.swift` (registers the settings view).
- UserDefaults key `weatherTemperatureUnit`.
