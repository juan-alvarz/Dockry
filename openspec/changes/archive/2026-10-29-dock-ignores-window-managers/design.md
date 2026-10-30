# Design

## Context

`DockPanel` is a borderless, non-activating `NSPanel` that can't become key or main. It
is still an ordinary window to Accessibility, whose position and size attributes are
settable. Dockry is the active app while a dock popover or Settings is open
(`PopoverFocus`), and window managers act on the active app's focused or main window, so
they can reach a dock panel. `DockController.layOut()` places panels only when screens or
settings change, so a moved panel stays moved.

## Goals / Non-Goals

**Goals:** no app can move a dock panel; any move is undone at once; VoiceOver still sees
the dock.

**Non-Goals:** changing when Dockry becomes active. Popovers need it for typing.

## Decisions

- **Refuse the frame setters.** `DockPanel` overrides `isAccessibilitySelectorAllowed(_:)`
  to refuse `setAccessibilityFrame:`, `setAccessibilityPosition:`, `setAccessibilitySize:`,
  `setAccessibilityMinimized:`, `setAccessibilityFullScreen:`, `setAccessibilityMain:` and
  `setAccessibilityFocused:`, and overrides those setters as no-ops, so the attributes
  read as not settable and writes do nothing. Alternative considered: hiding the panel
  from Accessibility (`isAccessibilityElement = false`) — rejected, it would hide the
  dock's buttons from VoiceOver.
- **Snap back.** `place(on:…)` remembers the frame it set; the panel observes its own
  `didMove`/`didResize` notifications and restores that frame when it differs. This covers
  any path the setters don't (private window server calls, AppKit itself).
- Not a subrole change: tools differ in which subroles they skip, so it wouldn't be a
  guarantee.

## Risks / Trade-offs

- [A snap-back fighting a legitimate resize] → only `place(on:…)` changes the remembered
  frame, and it is the only legitimate source of a dock frame.
- [The AX override isn't honored by some macOS version] → the snap-back still restores
  the dock.
