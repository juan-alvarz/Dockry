# widgets Specification

## Purpose

Widgets are small live tiles a profile can place in its dock, such as the clock or Claude usage. This spec covers what every widget shares: the catalog, how each describes itself, the Widgets settings page, sizing and when widgets may do work. Each widget's own behavior has its own spec.

## Requirements

### Requirement: Catalog
Dockry SHALL have these widgets, listed in this order: Clock, Calendar, Spotify, Claude Usage, Weather, Switch User and Trash. Each SHALL be in a profile at most once.

#### Scenario: Widgets settings list
- **WHEN** the user opens Settings › Widgets
- **THEN** the seven widgets are listed in that order

### Requirement: Self-description
Every widget SHALL describe itself with a name, a one-line summary, details (what clicking does and how it looks on a side dock), an icon (its app's icon when that app is installed, otherwise a symbol on a tile of its color), a category, its author ("Built in" for Dockry's) and what it needs, each need marked required or optional.

#### Scenario: Optional need
- **WHEN** the user views Spotify in Settings › Widgets
- **THEN** connecting a Spotify account is listed as optional, for search

### Requirement: Widgets settings page
Settings › Widgets SHALL show, for the selected widget, its description, a toggle per profile to show it there (adding it after the profile's other widgets), what it needs, and the widget's own settings if it has any. The list SHALL show which profiles each widget is in.

#### Scenario: Add a widget to a profile from Settings
- **WHEN** the user turns on Weather for Chill in Settings › Widgets
- **THEN** the weather widget appears after Chill's other widgets

### Requirement: Size and side docks
Widgets SHALL be designed for 48-point icons and scale with the dock's size. On a left or right dock each widget SHALL use a compact tile no wider than an icon.

#### Scenario: Side dock
- **WHEN** the dock moves to the left
- **THEN** the clock shows the time above AM/PM in an icon-wide tile

### Requirement: Work only while shown
Widgets that fetch data or watch another app SHALL do so only while at least one of them is on screen. Widgets that fetch from the network (Claude Usage, Weather) SHALL share one data source per kind, so switching profiles or having docks on several screens doesn't add requests or lose the last reading.

#### Scenario: Profile without the widget
- **WHEN** the active profile has no Claude Usage widget
- **THEN** Dockry makes no usage requests

### Requirement: Popovers take the keyboard while open
A widget's popover SHALL open on the side facing the middle of the screen; while it's open Dockry SHALL be the active app so its text fields get the keyboard, and closing it SHALL give the keyboard back to the app that had it, unless the user moved on or is in Settings.

#### Scenario: Type in the Spotify search
- **WHEN** the user opens the Spotify player and types in its search field
- **THEN** the typing goes to the search field, and closing the player returns to the previous app
