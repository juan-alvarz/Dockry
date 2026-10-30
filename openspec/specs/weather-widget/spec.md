# weather-widget Specification

## Purpose

Shows current conditions and temperature where the Mac is, with today's high and low, from Open-Meteo (free, no account or key), using the Mac's location at town level.

## Requirements

### Requirement: Location
The widget SHALL ask Location Services once for permission, at city-level accuracy (about 3 km). If location is denied or unknown it SHALL show a crossed-out location arrow explaining how to turn it on, and SHALL refresh as soon as permission is granted.

#### Scenario: Permission granted later
- **WHEN** the user turns on Location Services for Dockry in System Settings
- **THEN** the widget shows the weather without waiting for the next refresh

### Requirement: Forecast
The widget SHALL fetch the current temperature, conditions and day/night, and today's high and low, from Open-Meteo for the location rounded to three decimals, in the time zone of that place.

#### Scenario: Reading
- **WHEN** Open-Meteo reports 18.4° and code 2 during the day, high 21 and low 12
- **THEN** the widget shows a partly cloudy sun symbol, 18°, H21° L12°

### Requirement: Units
Settings › Widgets › Weather SHALL offer Temperature: System, Celsius or Fahrenheit, remembered across launches. System (the default) SHALL follow the Temperature setting in System Settings › General › Language & Region, or the region's measurement system when it isn't set, and its label SHALL name the unit that gives, such as "System (°F)". Changing the choice SHALL refresh the widget at once.

#### Scenario: Fahrenheit
- **WHEN** the choice is System and the Mac's Temperature setting is Fahrenheit
- **THEN** the widget asks for and shows Fahrenheit, and the option reads "System (°F)"

#### Scenario: Choose Celsius on a Fahrenheit Mac
- **WHEN** the Mac's Temperature setting is Fahrenheit and the user picks Celsius in Settings › Widgets › Weather
- **THEN** the widget shows Celsius right away and keeps doing so after Dockry restarts

### Requirement: Refresh
While a widget is on screen, the weather SHALL refresh every 30 minutes, and 5 minutes after a failure. A failure SHALL keep the last reading on screen; with none yet it shows a plain cloud explaining it will try again.

#### Scenario: Request fails
- **WHEN** the request fails after a reading was shown
- **THEN** the last reading stays and the next try is 5 minutes later

### Requirement: Conditions
Conditions SHALL map the WMO weather code to a multicolor symbol (with day and night variants for clear and partly cloudy skies) and a short summary shown as the tooltip.

#### Scenario: Night
- **WHEN** the code is 0 at night
- **THEN** the symbol is a moon with stars

### Requirement: Widget and click
On a bottom dock the widget SHALL show the symbol, temperature and high/low; on a side dock only the symbol and temperature. Clicking SHALL open the Weather app.

#### Scenario: Click
- **WHEN** the user clicks the weather widget
- **THEN** the Weather app opens
