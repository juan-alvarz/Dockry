# music-widget Specification

## Purpose
Shows what's playing in the Music app with its controls, and opens a player with progress, volume, shuffle, repeat and a search of the user's library, all without bringing Music to the front.

## Requirements

### Requirement: What's playing
The widget SHALL follow the track from the notification Music broadcasts on every playback change, which needs no permission, and SHALL ask Music once when it appears for what's playing now, only if Music is running. It SHALL show "Apple Music" and "Not playing" when Music is stopped or quits.

#### Scenario: Song starts
- **WHEN** Music starts playing a song
- **THEN** the widget shows its title and artist

#### Scenario: Music not running
- **WHEN** the widget appears while Music isn't running
- **THEN** it shows Not playing and Dockry doesn't launch Music or ask for permission

### Requirement: Artwork and controls
Album art, controls and search SHALL go through AppleScript, so macOS asks once whether Dockry may control Music; if declined, the widget SHALL still show the song and the controls SHALL do nothing. Controls SHALL leave Music in the background unless the user was in it, starting it hidden if it isn't running.

#### Scenario: Play while Music is closed
- **WHEN** the user presses play and Music isn't running
- **THEN** Music starts hidden and plays

### Requirement: Player
Clicking the song (or the art on a side dock) SHALL open the player: art, title and artist, progress that can be dragged to seek, previous/play-pause/next, shuffle, repeat cycling off → all → one, volume (sent once the slider rests), and Open Music, refreshed every second while open.

#### Scenario: Repeat one
- **WHEN** repeat is all and the user clicks repeat
- **THEN** Music repeats the current song and the button shows repeat-one

### Requirement: Library search
The player's search SHALL look up songs in the user's Music library after a short pause in typing, list up to 20 with title, artist and album, say when nothing is found, and play a clicked result in Music, which stays in the background.

#### Scenario: Search the library
- **WHEN** the user types part of a song title that's in their library and pauses
- **THEN** matching songs are listed, and clicking one plays it
