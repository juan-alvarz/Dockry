# profile-apps Specification

## Purpose

Optionally gives each profile its own open apps, or its own windows, like desktops on Linux or on a Mac: switching profiles hides what belongs to the others. Also shows which profile is playing sound. Fresh profiles' copies are covered in fresh-profiles.

## Requirements

### Requirement: Off by default
"Give each profile its own open apps" SHALL be off by default; while off (and with no fresh profiles involved), every open app shows in every profile and switching hides nothing.

#### Scenario: Feature off
- **WHEN** the setting is off and the user switches profiles
- **THEN** no app is hidden or shown

### Requirement: An app belongs to the profile it opened in
With the setting on, each open app SHALL belong to the profile active when it launched; apps already open when Dockry starts SHALL keep the profile they had before (by process) or join the active one. Finder SHALL be in every profile.

#### Scenario: Open in Work
- **WHEN** the user opens Notes while Work is active
- **THEN** Notes belongs to Work and shows in Work's dock only

### Requirement: Switching hides the other profiles' apps
In app mode, switching SHALL first show the new profile's apps that Dockry hid, then hide the other profiles' visible apps, keeping one of the new profile's apps (or Finder) in front so no hidden app comes back. Dockry SHALL only show again apps it hid itself, never ones the user hid.

#### Scenario: Switch from Work to Chill
- **WHEN** Mail belongs to Work and Music to Chill, and the user switches to Chill
- **THEN** Mail is hidden and Music is shown

#### Scenario: App the user hid
- **WHEN** the user hid Notes with ⌘H and then switches back to its profile
- **THEN** Notes stays hidden

### Requirement: Bringing an app forward moves it
In app mode, an app of another profile brought forward (⌘Tab, the dock, a link), other than within two seconds after a switch, SHALL move to the active profile.

#### Scenario: ⌘Tab to another profile's app
- **WHEN** Chill is active and the user ⌘Tabs to Mail, which belongs to Work
- **THEN** Mail now belongs to Chill and shows in Chill's dock

### Requirement: Window mode
With "Open a new app instance" also on, each window SHALL belong to the profile active when it opened. Switching SHALL put the new profile's windows back where they were, move the other profiles' windows just off screen, and hide apps with no window in the new profile.

#### Scenario: Browser with windows in two profiles
- **WHEN** Zen has one window in Work and one in Chill, and the user switches to Chill
- **THEN** only Zen's Chill window is on screen

#### Scenario: App without windows here
- **WHEN** an app only has windows in Work and the user switches to Chill
- **THEN** the app is hidden, so Mission Control doesn't show its parked windows

### Requirement: Window mode follows the app brought forward
In window mode, bringing forward an app with windows in the active profile SHALL raise one of those windows; one whose windows are all in other profiles SHALL switch to the first of those profiles by name.

#### Scenario: Click a window's app from another profile
- **WHEN** the user ⌘Tabs to an app whose only windows are in Work while in Chill
- **THEN** Dockry switches to Work

### Requirement: Dock shows the profile's apps
The dock SHALL show an open app in the active profile only when it belongs there; in window mode, when it has a window in the profile, or, for an app with no windows, when it opened there.

#### Scenario: Unpinned app of another profile
- **WHEN** Chill is active and Mail, unpinned, belongs to Work
- **THEN** Chill's dock doesn't show Mail

### Requirement: Nothing left parked or hidden
Turning the setting off SHALL put every parked window back and show every app Dockry hid. Changing mode SHALL start the new mode clean. Quitting Dockry SHALL put every parked window back.

#### Scenario: Quit in window mode
- **WHEN** Dockry quits while windows are parked off screen
- **THEN** they are moved back to where they were

### Requirement: Removed profile's apps
When a profile no longer exists, its apps SHALL belong to the active profile.

#### Scenario: Remove a profile with open apps
- **WHEN** the user removes Chill while Music belongs to it
- **THEN** Music belongs to the active profile

### Requirement: Sound per profile
While profiles keep their own apps, a speaker SHALL mark, in the menu bar menu, the switcher and on the dock's profile button (for other profiles), each profile whose app is playing sound, counting helper processes (a browser tab, say) as their app. It SHALL update within about two seconds.

#### Scenario: Music in another profile
- **WHEN** Work is active and Music in Chill is playing
- **THEN** the profile button shows a speaker, with Chill named in its tooltip

### Requirement: Renaming keeps a profile's apps and windows
Renaming a profile SHALL keep every open app and every window that belonged to it under the new name, whether or not it is the active profile. Apps and windows of other profiles SHALL not change profile.

#### Scenario: Rename a profile that isn't active
- **WHEN** Work is active, Music belongs to Chill, and the user renames Chill to Home
- **THEN** Music belongs to Home and still doesn't show in Work's dock

#### Scenario: Rename in window mode
- **WHEN** window mode is on, Zen has a window in Chill, and the user renames Chill to Home and switches to it
- **THEN** Zen's window comes back on screen

### Requirement: Saved ownership applies only to the same process
When Dockry starts, an already running app SHALL get the profile saved for it only if it is the same process that was saved (same process id and launch time); any other app SHALL join the active profile. A saved window's profile SHALL apply only to a window of the process it was saved for.

#### Scenario: Dockry restarts
- **WHEN** Music belongs to Chill, Dockry quits and reopens while Music keeps running
- **THEN** Music still belongs to Chill

#### Scenario: Mac restarts
- **WHEN** the Mac restarts and a different app gets the process id Music had
- **THEN** that app belongs to the active profile, not to Chill
