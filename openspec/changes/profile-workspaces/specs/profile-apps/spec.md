## ADDED Requirements

### Requirement: On by default
"Give each profile its own windows" SHALL be on by default. While off (and with no fresh profiles involved), every window shows in every profile and switching moves nothing.

#### Scenario: Setting off
- **WHEN** the setting is off and the user switches profiles
- **THEN** no window moves

### Requirement: Each window is in one profile
With the setting on, each window SHALL be in the profile active when it opened; windows open when Dockry starts SHALL keep the profile saved for them (same window number and process) or go to the profile their app opened in. Switching SHALL put the new profile's windows back where they were and move the other profiles' windows just off screen. No app SHALL be hidden. Afterwards, if the app in front has no window in the new profile, the app of the new profile's front window (or Finder) SHALL come forward.

#### Scenario: Browser with windows in two profiles
- **WHEN** Zen has one window in Projects and one in Chill, and the user switches to Chill
- **THEN** only Zen's Chill window is on screen

#### Scenario: Keyboard after a switch
- **WHEN** Zen's Chill window is in front and the user switches to Projects, where Notes has a window
- **THEN** Notes comes forward

### Requirement: An app coming forward without a window here
However an app comes forward (Dockry's dock, Raycast, ⌘Tab, a link, a click), with the setting on: if its window in front is in the active profile, nothing SHALL happen; if it has a window in the active profile behind another profile's, that one SHALL come forward; if all its windows are in other profiles, it SHALL get a new window in the active profile through its New Window menu item; with no windows, nothing SHALL happen.

#### Scenario: Zen from Raycast
- **WHEN** Zen only has windows in Chill and the user opens Zen from Raycast in Projects
- **THEN** a new Zen window opens in Projects and Dockry stays in Projects

#### Scenario: ⌘Tab
- **WHEN** Zen only has windows in Chill and the user ⌘Tabs to Zen in Projects
- **THEN** a new Zen window opens in Projects

## MODIFIED Requirements

### Requirement: Dock shows the profile's apps
The dock SHALL show an open app in the active profile when it has a window there or, for an app with no windows, when it opened there.

#### Scenario: Unpinned app of another profile
- **WHEN** Projects is active and Mail's only window is in Chill
- **THEN** Projects' dock doesn't show Mail

### Requirement: Nothing left parked or hidden
Turning the setting off SHALL put every parked window back. Quitting Dockry SHALL put every parked window back.

#### Scenario: Quit in window mode
- **WHEN** Dockry quits while windows are parked off screen
- **THEN** they are moved back to where they were

### Requirement: Sound per profile
A speaker SHALL mark, in the menu bar menu and the switcher, each profile with a window of an app playing sound, counting helper processes (a browser tab, say) as their app; for an app with no windows, the profile it opened in. It SHALL update within about two seconds. The dock's profile button SHALL show no speaker.

#### Scenario: Music in another profile
- **WHEN** Projects is active and Spotify, with its window in Chill, is playing
- **THEN** the switcher and the menu mark Chill, and the dock's profile button has no speaker

## REMOVED Requirements

### Requirement: Off by default
**Reason**: Replaced by "On by default" for the one remaining setting.
**Migration**: The setting is on unless turned off.

### Requirement: Switching hides the other profiles' apps
**Reason**: Hiding brought windows back as macOS brought the next app forward; windows are parked instead.
**Migration**: None.

### Requirement: Bringing an app forward moves it
**Reason**: The apps mode is gone; see "An app coming forward without a window here".
**Migration**: None.

### Requirement: Window mode
**Reason**: Now the only behaviour; see "Each window is in one profile".
**Migration**: "Open a new app instance" is deleted.

### Requirement: Window mode follows the app brought forward
**Reason**: Switching to the profile of an app's windows, and launcher detection, are replaced by a new window here.
**Migration**: None.
