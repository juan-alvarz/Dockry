# Design

## Context

`DockRowLayout` places items with `DockMagnification.place`, which scales items flagged
`magnifies` by distance from their center, and proposes the scaled size to each item. App
and folder icons are resizable images with an ideal size, so they grow with the proposal.
Widgets lay themselves out with fixed frames from `DockMetrics` (fonts, paddings,
`iconSize`), so a bigger proposal changes nothing; they also aren't flagged.

## Goals / Non-Goals

**Goals:** widgets grow like icons; wide widgets magnify fully under the pointer.

**Non-Goals:** hover labels for widgets; changing magnification for side docks beyond the
same rules.

## Decisions

- **Scale, don't re-lay-out.** A `MagnifiedWidget` wrapper measures the widget's natural
  size, reports it as its ideal size, and draws the widget with `scaleEffect` by the ratio
  of the size it's given to that natural size, anchored at the top leading corner (the
  layout's anchor). Hit testing follows the transform, so buttons stay clickable.
  Alternative considered: passing a scaled `DockMetrics` per widget — rejected, the layout
  can't set an environment per child, and popovers would be sized from the scaled metrics.
- **Full-size zone.** `DockMagnification.Item` gains `plateau` (default 0): half the length
  around its center where the distance to the pointer counts as zero. Widgets pass
  `(length - iconSize) / 2`, so any point over a widget is as close as the center of an
  icon. Icons keep 0, which leaves their behavior unchanged. Pure and unit tested.
- Frames read for dragging are taken while magnification is paused (it pauses during
  drags), so drag math still sees unscaled lengths.

## Risks / Trade-offs

- [Wide widgets grow large: Spotify at 80/48 is about 330 points] → same factor as icons,
  as the macOS Dock does for every item; users set the magnified size.
- [One frame at natural size before the wrapper has measured] → it starts at scale 1,
  which is the unmagnified state anyway.
