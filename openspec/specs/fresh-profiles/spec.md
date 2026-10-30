# fresh-profiles Specification

## Purpose

A fresh profile starts its apps from scratch, like a new Mac: it runs its own copies, and browsers and Electron apps keep their own sign-ins, history and tabs apart from every other profile. This spec covers choosing one, keeping its apps apart, and its data.

## Requirements

### Requirement: Chosen at creation, fixed after
Creating a profile SHALL ask whether it has shared apps or fresh apps; the choice SHALL not be changeable afterwards. A fresh profile is first named "Fresh Profile".

#### Scenario: Create a fresh profile
- **WHEN** the user clicks + in Settings › Profiles and chooses Fresh apps
- **THEN** a profile named "Fresh Profile" with fresh apps is added and selected

### Requirement: Always kept apart
A fresh profile's own copies SHALL never show in, or stay visible in, another profile, and other profiles' apps SHALL never show in it, whether or not "Give each profile its own open apps" is on. Bringing forward an app that belongs to a fresh profile, or a shared app while a fresh profile is active, SHALL switch to the app's profile.

#### Scenario: Switch away from a fresh profile
- **WHEN** the user switches from a fresh profile to Work
- **THEN** the fresh profile's copies are hidden and Work's apps shown

#### Scenario: ⌘Tab to a fresh profile's copy
- **WHEN** Work is active and the user ⌘Tabs to a fresh profile's copy of Chrome
- **THEN** Dockry switches to the fresh profile

### Requirement: Own data for browsers and Electron apps
A fresh profile's copy of a Firefox-based browser SHALL run with its own profile folder, and of a Chromium-based browser or Electron app with its own user data folder, kept per profile and app under `~/Library/Application Support/Dockry/App Data/<profile>/<bundle id>`. Other apps' copies SHALL share the app's usual data.

#### Scenario: First open
- **WHEN** a fresh profile opens Chrome for the first time
- **THEN** Chrome starts signed out with no history

#### Scenario: Next open
- **WHEN** the same profile opens Chrome again later
- **THEN** it has the tabs and sign-ins from last time in that profile

### Requirement: Data follows renames
Renaming a fresh profile SHALL move its app data folder to the new name.

#### Scenario: Rename
- **WHEN** a fresh profile named Clients is renamed to Agency
- **THEN** its app data is under `App Data/Agency`

### Requirement: Removing asks about the data
Removing a fresh profile SHALL ask first. Confirming SHALL move its app data folder to the Trash unless the user checked "I want to preserve the data"; cancelling keeps the profile.

#### Scenario: Remove and keep the data
- **WHEN** the user removes a fresh profile with the box checked
- **THEN** the profile is gone and its app data stays where it was

#### Scenario: Remove with data
- **WHEN** the user removes a fresh profile with the box unchecked
- **THEN** its app data folder is in the Trash, where it can be put back

### Requirement: Marked everywhere
Fresh profiles SHALL carry a badge in the dock's profile button, the switcher, the menu bar menu and Settings. The badge is a white circle unless the user picks another symbol in Settings › General › Profiles.

#### Scenario: Pick a badge
- **WHEN** the user picks the leaf symbol
- **THEN** every fresh profile's badge becomes a leaf

### Requirement: Show the data
Settings › Profiles SHALL offer Show App Data in Finder for a fresh profile, creating the folder if it doesn't exist yet.

#### Scenario: Before any app opened
- **WHEN** the user clicks Show App Data in Finder for a new fresh profile
- **THEN** Finder shows its (empty) app data folder
