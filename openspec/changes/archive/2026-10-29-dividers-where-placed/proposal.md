# Proposal

## Why

The user wants dividers wherever they put them. The dock hides dividers at either end or
next to another divider, and the previous change answered that by greying out Add Divider
where it would be hidden. In use it was greyed out even where a divider would show (after
an app followed by open apps), and either way it stopped the user from placing one.

## What Changes

- Add Divider is always enabled and the divider always shows where it was added, including
  at an end or right next to another divider.
- A divider is left out only when hidden things alone separate it from an end or from
  another divider (an empty group of open apps, an uninstalled app), so dividers don't pile
  up when the dock has less to show.
- **Removed**: greying out Add Divider.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dock-contents`: "Missing apps and empty dividers" changes its divider rule;
  "Add Divider only where it shows" is removed.

## Impact

- `Sources/DockryCore/DockLayout.swift` (`elements`; `addsVisibleDivider` removed),
  `DockLayoutTests`.
- `Sources/Dockry/DockView.swift` (environment check and disabled state removed).
