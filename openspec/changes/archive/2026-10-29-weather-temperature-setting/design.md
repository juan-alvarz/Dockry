# Design

## Context

`WeatherMonitor.usesFahrenheit` reads `AppleTemperatureUnit`, else the locale. The
monitor is shared and refreshes every 30 minutes while a widget is visible;
`refreshNow()` restarts the loop. `DockWidget` takes an optional `makeSettings` view,
shown in Settings › Widgets.

## Goals / Non-Goals

**Goals:** a per-app unit choice with System as the default.

**Non-Goals:** converting a reading already shown (the next fetch asks in the new unit).

## Decisions

- `DockryCore.TemperatureUnit` (`system`, `celsius`, `fahrenheit`, raw strings) with
  `usesFahrenheit(systemSetting:regionUsesUS:)`, pure and tested.
- Stored with `@AppStorage("weatherTemperatureUnit")` in `WeatherSettings`; the monitor
  reads the same key when it builds a request. The settings view calls
  `WeatherMonitor.shared.unitChanged()`, which calls `refreshNow()`; with no widget
  showing, the next appearance fetches in the new unit anyway.

## Risks / Trade-offs

- [A refresh right after a change could hit Open-Meteo twice in a row] → it's free and
  keyless, and changes are rare.
