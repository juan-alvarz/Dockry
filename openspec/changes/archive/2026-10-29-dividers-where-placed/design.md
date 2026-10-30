# Design

## Context

`DockLayout.elements` drops a divider when nothing shown precedes it, when the previous
shown element is a divider, and when it ends the row. `DockEditMenu` greys out Add Divider
using `addsVisibleDivider` through the environment; in the installed app it was greyed out
after Zed although the core check returns true for that spot (checked against the user's
profiles.json). The cause in the menu wasn't found, since the menu can't be opened from the
implementation shell; the check is removed rather than fixed.

## Goals / Non-Goals

**Goals:** a divider shows where it's added; hidden content doesn't leave stray dividers.

**Non-Goals:** cleaning up dividers already saved.

## Decisions

- `elements` tracks whether anything since the last shown element was hidden. A divider is
  dropped only when that's true and it would otherwise start the row or follow another
  divider; after the loop, a trailing divider is dropped only when hidden items follow it.
  Directly adjacent dividers, or a divider at an end with nothing at all beyond it, show.
- `addsVisibleDivider`, its environment key and the disabled state go.

## Risks / Trade-offs

- [Two dividers placed side by side show as a double line] → that's what was asked for;
  Remove Divider takes one away.
- [In the Default profile with no extra open apps, a divider added after Finder sits next
  to the existing one, both before the empty open-apps group] → the trailing one is cut off
  only by hidden things, so it's dropped until an app opens.
