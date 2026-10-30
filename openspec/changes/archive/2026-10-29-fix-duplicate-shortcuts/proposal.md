# Proposal

## Why

Nothing stops two profiles, or a profile and the profile switcher, from getting the same
shortcut. The second one silently doesn't work, and Settings blames "another app"
(finding 4).

## What Changes

- Recording a shortcut that another of Dockry's shortcuts already has is refused, naming
  who has it.
- Shortcuts that clash anyway (profiles.json edited by hand, a duplicated file) are
  reported as clashing with another Dockry shortcut, not with another app.
- Shortcuts are compared by key and modifiers only, not by the key's printed label.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `keyboard-shortcuts`: adds a requirement that each shortcut belongs to one Dockry action.

## Impact

- `Sources/DockryCore/KeyShortcut.swift` (same-keys comparison, duplicate finder) and tests.
- `Sources/Dockry/HotKeys.swift`, `ShortcutRecorder.swift`, `SettingsWindow.swift`.
