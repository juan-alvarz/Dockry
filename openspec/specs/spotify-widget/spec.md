# spotify-widget Specification

## Purpose

Shows what's playing in Spotify with play/pause, previous and next, and opens a player with progress, volume, shuffle, repeat and search, all without bringing Spotify to the front.

## Requirements

### Requirement: What's playing
The widget SHALL follow the track from the notification Spotify broadcasts on every playback change, which needs no permission, and SHALL ask Spotify once when it appears for what's playing now. It SHALL show "Spotify" and "Not playing" when Spotify is stopped or quits.

#### Scenario: Song changes
- **WHEN** Spotify moves to the next song
- **THEN** the widget shows the new title and artist

#### Scenario: Spotify quits
- **WHEN** Spotify quits
- **THEN** the widget shows Not playing

### Requirement: Album art and controls need Automation
Album art and every control SHALL go through AppleScript, so macOS asks once whether Dockry may control Spotify. If the user declines, the widget SHALL still show the song and the controls SHALL do nothing. Scripts SHALL run in separate processes so a slow Spotify never freezes the dock.

#### Scenario: Automation declined
- **WHEN** the user didn't allow Dockry to control Spotify
- **THEN** the song shows with the green note instead of album art

### Requirement: Controls keep Spotify in the background
Play/pause, previous, next, seeking, volume, shuffle, repeat and playing a search result SHALL leave Spotify in the background, unless the user was already in it. If Spotify isn't running, a command SHALL start it hidden first. Open Spotify in the player SHALL be the one way to bring it forward.

#### Scenario: Play while Spotify is closed
- **WHEN** the user presses play and Spotify isn't running
- **THEN** Spotify starts hidden and plays

### Requirement: Player popover
Clicking the song (or the album art on a side dock) SHALL open the player: artwork, title and artist, progress that can be dragged to seek, volume, shuffle and repeat, refreshed every second while open. Volume changes SHALL be sent only once the slider rests.

#### Scenario: Seek
- **WHEN** the user drags the progress bar to 1:30
- **THEN** Spotify plays from 1:30

### Requirement: Side dock tile
On a side dock the widget SHALL show the album art above previous, play/pause and next.

#### Scenario: Left dock
- **WHEN** the dock is on the left
- **THEN** the Spotify tile is icon-wide with the art on top
