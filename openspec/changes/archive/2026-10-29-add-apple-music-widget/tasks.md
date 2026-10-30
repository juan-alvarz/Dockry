# Tasks

## 1. Core

- [x] 1.1 Add `WidgetKind.music`, its `WidgetInfo` and catalog place, and `AppleMusic.swift` (track, playback, search, scripts), and verify with new `AppleMusicTests` and `swift test`

## 2. App

- [x] 2.1 Move the background sending into `AppleScript.tell(_:command:)` and use it from `SpotifyPlayer`, and verify `swift build`
- [x] 2.2 Add `MusicPlayer`, `MusicWidget` and `MusicPopover` (player, repeat cycle, library search), register the widget, and verify `swift build`
- [x] 2.3 Add `scripts/fake-music-track.swift` (posts Music's notification), update README and CHANGELOG, and verify the README lists `music`

## 3. On-screen check

- [x] 3.1 Install, add the Apple Music widget, post the test notification, and confirm by screenshot that the widget shows the posted title and artist; record that controls, art and search need Music automation and weren't exercised here

On-screen check (installed build, Music not running): the widget showed "Apple Music · Not playing"; after `scripts/fake-music-track.swift` it showed "Clair de Lune · Claude Debussy" with the pause button; after a posted "Stopped" it went back to Not playing; Music was never launched. Not checked here: album art, the controls, the player popover and library search, which all need Dockry to control Music (an Automation prompt) and real playback.
