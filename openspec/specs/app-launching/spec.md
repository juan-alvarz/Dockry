# app-launching Specification

## Purpose

What clicking an app in the dock (or `dockry://open/<bundle id>`) does, including when profiles keep their own apps or run their own copies, and how Dockry quits apps from the dock.

## Requirements

### Requirement: Click to open or switch
Clicking an app SHALL launch it if it isn't running, or bring it forward and reopen a window if it is, as the macOS Dock does.

#### Scenario: App not running
- **WHEN** the user clicks Mail and Mail isn't running
- **THEN** Mail launches

#### Scenario: App running
- **WHEN** the user clicks Safari while it runs in the background
- **THEN** Safari comes forward

### Requirement: Open by URL
`dockry://open/<bundle id>` SHALL do exactly what clicking that app in the dock would do in the active profile. An app that isn't installed SHALL be ignored.

#### Scenario: Script opens Safari
- **WHEN** `open dockry://open/com.apple.Safari` runs
- **THEN** Safari opens or comes forward as a dock click would

### Requirement: Several copies of an app
When several copies of an app run and one belongs to the active profile, clicking it SHALL bring that copy forward, not another profile's.

#### Scenario: Copy per profile
- **WHEN** a fresh profile and a shared profile each run a copy of Chrome and the fresh profile is active
- **THEN** clicking Chrome brings the fresh profile's copy forward

### Requirement: Fresh profiles open their own copy
In a profile with fresh apps, clicking an app that has no copy in the profile SHALL open a new copy of it with the profile's own data.

#### Scenario: Chrome in a fresh profile
- **WHEN** the user clicks Chrome in a fresh profile while Chrome runs in another profile
- **THEN** a separate copy of Chrome opens with the fresh profile's data

### Requirement: Usual copy beside a fresh profile's
In a profile without fresh apps, clicking an app whose only running copies belong to fresh profiles SHALL open a new copy with the app's usual data.

#### Scenario: Back from a fresh profile
- **WHEN** only a fresh profile's copy of Slack runs and the user clicks Slack in Work
- **THEN** a new copy of Slack opens with the user's own data

### Requirement: New window in this profile
With per-profile apps and "Open a new app instance" on, clicking an app whose windows are all in other profiles SHALL open a new window of it in this profile through its own New Window (⌘N) menu item and bring it forward once the window exists. An app with no such item SHALL have its windows moved to this profile instead.

#### Scenario: Browser open in another profile
- **WHEN** Zen only has windows in Chill and the user clicks Zen in Work
- **THEN** Zen opens a new window in Work and Chill's windows stay in Chill

### Requirement: Quit from the dock
Quit SHALL ask the app to quit as its own Quit command would, so it can ask to save first. With Accessibility access Dockry presses the app's ⌘Q menu item; otherwise it sends the quit Apple event, and if macOS doesn't allow that it explains how to allow it in Privacy & Security › Automation.

#### Scenario: Unsaved document
- **WHEN** the user chooses Quit for an app with unsaved changes
- **THEN** the app asks whether to save, as if the user had pressed ⌘Q in it

#### Scenario: Automation not allowed
- **WHEN** there's no Accessibility access and Dockry isn't allowed to control the app
- **THEN** an alert offers to open the Automation settings
