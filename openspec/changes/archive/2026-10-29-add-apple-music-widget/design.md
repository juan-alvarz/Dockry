# Design

## Context

The Spotify widget follows a distributed notification for the track and uses `osascript`
processes (`AppleScript.run`) for art and controls, launching Spotify hidden and hiding it
again if a command brings it forward. Music posts `com.apple.Music.playerInfo` with
`Player State`, `Name`, `Artist`, `Album` and `PersistentID`, and its scripting dictionary
has `player state`, `player position`, `sound volume`, `shuffle enabled`, `song repeat`,
`raw data` of artworks, `persistent ID`, `search` and the transport commands.

## Goals / Non-Goals

**Goals:** parity with the Spotify widget for what Music can do locally.

**Non-Goals:** Apple Music catalog search (needs a MusicKit developer token); a generic
"Now Playing" for any app (the private framework for it no longer works for third-party
apps since macOS 15.4).

## Decisions

- **Pure parts in `DockryCore/AppleMusic.swift`:** `MusicTrack` (from the notification and
  from script output), `MusicPlayback` (position, duration, volume, shuffle, repeat
  off/one/all), `MusicSearchResult`, and the scripts: current track, playback, artwork to a
  file, search (query escaped for AppleScript strings), play by persistent ID (accepted
  only as hex). All unit tested.
- **Art through a file.** Music has no artwork URL; the script writes `raw data` of the
  current track's first artwork to `NSTemporaryDirectory()/dockry-music-<persistent ID>`,
  and the widget loads that file URL through the existing artwork cache. One file per
  track, so the cache never shows the previous track's art.
- **Shared sending.** `SpotifyPlayer.send`/`launchHidden` move to
  `AppleScript.tell(_:command:)`, used by both players, unchanged in behavior.
- **Views mirror Spotify's** (`MusicWidget`, `MusicPopover`), with Music's red and its
  three-state repeat. `SpotifyArtwork` takes the placeholder color.
- **Search** uses `search library playlist 1 for "…" only songs` (not the localized
  "Library" name), first 20 results.

## Risks / Trade-offs

- [Music's notification keys are undocumented] → same risk the Spotify widget already
  takes; the initial AppleScript read covers what's playing when the widget appears.
- [Can't exercise Music from the implementation shell without a permission prompt] → the
  on-screen check uses a posted test notification; controls, art and search are reported
  as unverified.
