# Proposal

## Why

Dockry has a Spotify widget but nothing for Apple Music, the player every Mac has.

## What Changes

- New built-in widget, Apple Music (`widget:music`): what's playing in the Music app with
  album art, previous, play/pause and next, like the Spotify widget.
- Clicking the song opens a player: progress you can drag, volume, shuffle, repeat (off,
  all, one) and a search of the user's Music library that plays songs without bringing
  Music to the front, plus Open Music.
- The Spotify widget's "keep the app in the background" AppleScript sending is shared by
  both widgets.

## Capabilities

### New Capabilities

- `music-widget`: Apple Music now playing, controls, player and library search.

### Modified Capabilities

- `widgets`: the catalog gains Apple Music, after Spotify.
- `profiles-file`: `music` becomes a valid widget name.

## Impact

- `Sources/DockryCore` (`WidgetKind.music`, its `WidgetInfo`, `AppleMusic.swift` with track,
  playback and search scripts and parsing) and tests.
- `Sources/Dockry/Widgets/Music/` (new), `Widgets/Spotify/SpotifyPlayer.swift` (shared
  sending), `SpotifyWidget.swift` (artwork placeholder color), `WidgetView.swift`.
- macOS asks once to let Dockry control Music. Searching the Apple Music catalog (not the
  library) would need a developer token and is out of scope.
