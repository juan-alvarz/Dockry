# Proposal

## Why

"System" follows macOS's Temperature setting, which on many Macs isn't set and falls back
to the region (°F for a US region), while the Weather app keeps a setting of its own. The
result looks wrong next to Weather and needs explaining. Two plain choices don't.

## What Changes

- **BREAKING**: the Temperature choice is Celsius or Fahrenheit only; System is removed.
- Celsius is the default. A saved "system" choice (or none) reads as Celsius.
- Dockry no longer reads macOS's `AppleTemperatureUnit` or the region for the weather.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `weather-widget`: "Units" offers Celsius and Fahrenheit, Celsius by default.

## Impact

- `Sources/DockryCore/Weather.swift` (`TemperatureUnit`), `WeatherTests`, `WidgetInfo.swift`.
- `Sources/Dockry/Widgets/Weather/WeatherMonitor.swift`, `WeatherSettings.swift`.
- README, CHANGELOG.
