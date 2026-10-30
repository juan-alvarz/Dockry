# Design

## Context

`Profile.defaults` is the only source of the starting profiles: `ProfileLibrary` uses it
for an empty list and `ProfileFile.load` for a missing or unreadable file. Nothing else
in the app or CI depends on Work or Chill existing.

## Goals / Non-Goals

**Goals:** a first launch that shows a dock with Finder and asks for nothing.

**Non-Goals:** changing existing users' profiles; changing what new profiles added in
Settings contain.

## Decisions

- `Profile.defaults` becomes
  `[Profile(name: "Default", symbol: "house.fill", items: [.app("com.apple.finder"), .divider, .runningApps])]`.
  The divider keeps Finder apart from open apps, as the macOS Dock does; with no open
  apps it isn't shown (trailing dividers are dropped). Alternative considered: no
  divider, `[.app(finder), .runningApps]` — rejected, Finder would run into the open apps.

## Risks / Trade-offs

- [A user with an unreadable profiles.json now sees one profile instead of two while
  fixing it] → the warning in the menu and Settings is unchanged, and the file is still
  never overwritten.
