## MODIFIED Requirements

### Requirement: Picture per profile
Dockry SHALL set the active profile's wallpaper, or the macOS default picture for a profile without one, on every screen when the profile becomes active, at launch and when screens change, keeping each screen's picture options and skipping screens already showing it. It SHALL never learn or restore pictures from what the screens show.

#### Scenario: Switch to a profile with a wallpaper
- **WHEN** the user switches from Projects to Chill, which has a picture
- **THEN** every screen shows Chill's picture

#### Scenario: Back to a profile without one
- **WHEN** the user switches back to a profile without a wallpaper
- **THEN** every screen, both of them, shows the macOS default picture, never Chill's

### Requirement: Choosing a wallpaper
Settings › Profiles SHALL let the user choose an image file as a profile's wallpaper, starting in the system's desktop pictures, show a thumbnail of it, and offer None, which shows the macOS default picture.

#### Scenario: Change the active profile's wallpaper
- **WHEN** the user picks a new wallpaper for the active profile
- **THEN** the desktop changes to it without switching profiles

## ADDED Requirements

### Requirement: Updating keeps the pictures
Once, on the first launch after updating, profiles without a wallpaper SHALL get the picture the first screen shows as theirs, unless it is another profile's wallpaper.

#### Scenario: Updating from 0.2.0
- **WHEN** Projects has no wallpaper and the screens show the user's own picture
- **THEN** Projects gets that picture as its wallpaper

## REMOVED Requirements

### Requirement: The user's own pictures are saved
**Reason**: A picture learned from the screens could be another profile's, which then showed in every profile without one.
**Migration**: See "Updating keeps the pictures"; `ownWallpapers` is deleted.
