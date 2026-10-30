# wallpapers Specification

## Purpose

Each profile can have its own desktop picture, shown while it's active, with the user's own picture back for profiles without one. The new picture comes in with a short transition so it shows at once.

## Requirements

### Requirement: Picture per profile
A profile with a wallpaper SHALL set it as the desktop picture on every screen when it becomes active, keeping each screen's picture options. Profiles without one SHALL show the user's own pictures.

#### Scenario: Switch to a profile with a wallpaper
- **WHEN** the user switches from a profile without a wallpaper to one with a picture
- **THEN** every screen shows that picture

#### Scenario: Back to a profile without one
- **WHEN** the user switches back
- **THEN** each screen shows the picture it had before

### Requirement: The user's own pictures are saved
Before a profile's picture first replaces the user's, Dockry SHALL save each screen's current picture as the user's own. At launch it SHALL not overwrite pictures already saved, since what's showing may be a profile's.

#### Scenario: Launch while a profile picture shows
- **WHEN** Dockry restarts while a profile's wallpaper is showing
- **THEN** the saved pictures are still the user's own

### Requirement: Transition
With the animation on (the default), the new picture SHALL come in over the desktop (below its icons) as Fade, Blur or Zoom, lasting 0.1 to 1 second (0.3 by default), from pictures decoded ahead of time. With it off, the picture SHALL change whenever macOS shows it, and no pictures SHALL be kept decoded.

#### Scenario: Blur
- **WHEN** the transition is Blur and the user switches to a profile with a wallpaper
- **THEN** the picture comes into focus as it fades in

#### Scenario: Animation off
- **WHEN** the animation is off
- **THEN** Dockry keeps no decoded pictures in memory

### Requirement: Choosing a wallpaper
Settings › Profiles SHALL let the user choose an image file as a profile's wallpaper, starting in the system's desktop pictures, show a thumbnail of it, and offer None to go back to the user's own.

#### Scenario: Change the active profile's wallpaper
- **WHEN** the user picks a new wallpaper for the active profile
- **THEN** the desktop changes to it without switching profiles
