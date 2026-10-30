# Design

## Context

`KeyShortcut` is `Hashable` over key code, modifier flags and the display label `key`, so
two recordings of the same keys can differ. `HotKeys.apply` registers each with Carbon;
a combination already registered (by anyone, Dockry included) fails and lands in `taken`,
which the recorder shows as "Another app already uses this shortcut."

## Goals / Non-Goals

**Goals:** prevent clashes when recording; report the ones that exist correctly.

**Non-Goals:** changing profiles.json; resolving clashes automatically.

## Decisions

- **Compare by keys.** Add `KeyShortcut.sameKeys(as:)` (key code and the ⌃⌥⇧⌘ modifiers)
  and `KeyShortcut.duplicates(in:) -> Set<Int>`, the indexes of entries whose keys an
  earlier entry already has. Pure and unit tested in `DockryCore`.
- **HotKeys skips duplicates.** `apply` registers only the first of each combination and
  publishes `duplicated`, the later entries' shortcuts; they aren't put in `taken`.
- **Recorder asks who owns it.** `ShortcutRecorder` takes `usedBy: (KeyShortcut) -> String?`;
  Settings answers with a profile name or "the profile switcher", excluding the shortcut's
  own owner. A clashing recording keeps the old shortcut and shows "Already used by X."
  The message for an existing clash is "Also used by another Dockry shortcut; only one works."

## Risks / Trade-offs

- [The first profile wins a hand-made clash, which may not be what the user meant] → the
  message tells them, and recording a new one fixes it.
