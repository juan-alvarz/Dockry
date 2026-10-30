# time-widgets Specification

## Purpose

The Clock and Calendar widgets: the time and today's date in the dock, with the Clock app and a month calendar one click away.

## Requirements

### Requirement: Clock
The clock SHALL show the current time in the Mac's 12- or 24-hour format, updated every minute. On a side dock, the time SHALL sit above AM/PM (when the format uses it) in an icon-sized tile.

#### Scenario: 24-hour Mac
- **WHEN** the Mac uses a 24-hour clock at 17:42
- **THEN** the widget shows 17:42 with no AM/PM

### Requirement: Clicking the clock
Clicking the clock SHALL open the Clock app, or the Date & Time settings where there's no Clock app.

#### Scenario: Click
- **WHEN** the user clicks the clock on a Mac with the Clock app
- **THEN** the Clock app opens

### Requirement: Calendar tile
The calendar widget SHALL show the abbreviated month in red capitals above the day of the month, like a desk calendar page, and change at midnight.

#### Scenario: New day
- **WHEN** the date changes while the widget is showing
- **THEN** it shows the new day within a minute

### Requirement: Month popover
Clicking the calendar SHALL open the current month as weeks starting on the user's first weekday, today circled in red, with buttons for the previous and next month, Today to come back, and Open Calendar.

#### Scenario: Week starts on Monday
- **WHEN** the user's calendar starts weeks on Monday
- **THEN** the first column of the month grid is Monday

#### Scenario: Browse months
- **WHEN** the user clicks the next-month arrow twice and then Today
- **THEN** the popover shows the current month again
