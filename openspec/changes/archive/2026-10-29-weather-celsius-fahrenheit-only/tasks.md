# Tasks

## 1. Two units

- [x] 1.1 Reduce `TemperatureUnit` to celsius and fahrenheit with Celsius as the fallback for missing or unknown saved values, and verify with `WeatherTests` and `swift test`
- [x] 1.2 Show only Celsius and Fahrenheit in Settings, read only that choice in `WeatherMonitor`, update the widget description, README and CHANGELOG, and verify `swift build`

## 2. On-screen check

- [x] 2.1 Install the build, open Settings › Widgets › Weather with `-showWidget weather`, and confirm by screenshot that it offers Celsius and Fahrenheit only, with the dock in °C matching the Weather app
- [x] 2.2 Save Fahrenheit, restart Dockry, and confirm by screenshot that the dock shows °F and Settings shows Fahrenheit selected

Checked by screenshot on the installed build: with the old "system" value saved, Settings offers Celsius and Fahrenheit only, Celsius selected, dock 19° (Weather app: 19°). With Fahrenheit saved and Dockry restarted, dock 65° (H85° L64°) and Fahrenheit selected. Not checked: clicking the picker itself (values were set with `defaults write`, then Dockry restarted).
