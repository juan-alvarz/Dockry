# Proposal

## Why

Settings › Widgets › Weather offers "System", but doesn't say which unit that is. On a Mac
whose region is the US and with no Temperature setting, System means Fahrenheit, while
the Weather app can be set to Celsius on its own. The user saw "System" selected and °F
in the dock and reasonably read it as broken.

## What Changes

- The System option names the unit it resolves to, as the Weather app does:
  "System (°F)" or "System (°C)".
- The explanation under the picker says System is macOS's setting, not the Weather app's.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `weather-widget`: "Units" says the System choice shows which unit it means.

## Impact

- `Sources/Dockry/Widgets/Weather/WeatherSettings.swift`, `WeatherMonitor.swift`
  (expose the resolved unit). No stored data changes.
