## Context

The user doesn't run Dockry while it's built and tests it once done. So the decisions are
pure code in DockryCore with a test per case they reported, and the app only reads macOS
(Accessibility, the window list) and moves windows.

## Decisions

### Workspaces of Dockry's own, not macOS desktops

macOS desktops can't be created by an app, need shortcuts and Mission Control setup, and
animate every switch; the user rejected them after trying. Parking windows just past the
bottom right corner of all screens (one point stays visible, as macOS won't move a window
wholly off) is what AeroSpace does in daily use. Limit: Mission Control shows every
profile's windows together.

### One mode, one record per window

`ProfileWindowRecords` maps the window server's window number to its profile, process and,
while parked, where it was. A window seen for the first time goes to the profile its app
opened in (at launch) or the active profile (when it opens). The format is the one older
versions saved, so records carry over. `switchPlan` lists what to park and bring back;
with the setting off only windows a fresh profile is involved in move.

### The same rule however an app comes forward

`ProfileAppRules.activated` looks only at where the app's windows are and which window is
in front: a window here in front, nothing; a window here behind another profile's, raise
it; windows only elsewhere, open a new window here; no windows, nothing. Raycast, ⌘Tab,
the dock and links all get this answer, so nothing depends on telling them apart or on
event order. The one guard left is Dockry's own: for 3 s after pressing New Window, the
app coming forward before its window is there is ignored.

### Nothing hidden, keyboard follows

Hiding apps caused windows to come back as macOS brought the next app forward. Now apps
are never hidden. After a switch, if the app in front has no window in the new profile,
the app of the profile's front window comes forward (or Finder).

### Wallpapers without memory

The old code learned "the user's own picture" from the screens and once took another
profile's for it. Now a profile's picture (or the macOS default) is set on every screen;
nothing is remembered. To keep what the user saw, a one-time step gives profiles without
a wallpaper the picture showing at the update.

## Risks

- Windows that refuse to move stay on screen (logged as "Dockry windows:").
- Windows on another macOS desktop aren't seen by Accessibility until that desktop shows.
- ⌘Tab to an app whose windows are all in another profile opens a window here instead of
  switching profiles, as the user chose.
