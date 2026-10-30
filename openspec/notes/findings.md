# Findings from the OpenSpec onboarding read

Things noticed while reading the code to write the baseline specs. Nothing here has been
changed, and the specs in `openspec/specs/` describe what the code does today, so a fix
for any item below is a change with its own delta spec. Each item says how sure it is: **confirmed** (read the code path end to end),
**likely** (reasoned from the code, not reproduced) or **question** (needs a decision).
Good candidates for the first OpenSpec changes (`/opsx:propose`).

Baseline at the time of writing: `swift test` runs 100 tests, all passing.

## Bugs

1. **Renaming a profile that isn't active moves its open apps to the active profile.**
   *Confirmed.* `ProfileApps` reacts to library changes by reassigning every app whose
   owner name no longer exists to `library.activeProfileName`, not to the new name
   (`Sources/Dockry/ProfileApps.swift`, the `store.$library` sink in `init`). Renaming the
   active profile happens to work because the active name is the new name.
   The baseline `profile-apps` spec doesn't promise either way; the fix would be a change
   that adds a "renaming keeps its apps and windows" requirement.

2. **Renaming a profile strands its windows in window mode.** *Confirmed.*
   `ProfileWindows` records keep the old profile name and nothing updates them, so after a
   rename the profile's windows match no profile and stay parked off screen until window
   mode is turned off or Dockry quits (`Sources/Dockry/ProfileWindows.swift`).

3. **Typing a new name renames on every keystroke.** *Confirmed.* The profile editor's
   name field writes through on each change (`SettingsWindow.swift`, `ProfileEditor.rename`).
   Each keystroke saves `profiles.json`, re-registers hot keys and, for a fresh profile,
   moves its `App Data` folder. Combined with 1 and 2, typing a name drags apps around.

4. **Two of Dockry's own shortcuts that are the same are reported as "another app".**
   *Likely.* Nothing stops two profiles (or a profile and the switcher) from recording the
   same shortcut. The second Carbon registration fails and `HotKeys.taken` marks it, so
   Settings says "Another app already uses this shortcut."

5. **Per-process ownership survives a reboot by pid.** *Likely.* `appProfiles` maps pid →
   profile and is read at launch for apps that were already running. After a restart of
   the Mac, pids are reused, so an app can start in an unrelated profile. Same for
   `profileWindows`, but window numbers are checked against the window server, which makes
   collisions rarer.

6. **README shows a screenshot that isn't in the repo.** *Confirmed.*
   `docs/screenshots/12-settings-widgets.png` is referenced in `README.md` but not tracked.
   The README also says to choose **Reload Profiles** after fixing a broken file; there is
   no such menu item. The menu's warning opens Settings › Profiles, which has
   **Reload from File**.

20. **Window managers can move the dock.** *Reported* (seen with Rectangle: its maximize
    shortcut moved Dockry's dock). *Likely cause:* the dock is an ordinary `NSPanel`, so
    Accessibility exposes it as a window whose position and size can be set. Dockry becomes
    the active app while a popover is open (`PopoverFocus.begin`), and doesn't always hand
    focus back (`PopoverFocus.end` skips that while Settings is open). A tool acting on
    the front app's focused window can then grab the dock. Nothing puts the panel back
    until the next layout pass. The macOS Dock is never a target for these tools.
    Fix as a change adding a "dock can't be moved by other apps" requirement to
    `dock-appearance`.

## Inconsistencies

7. The menu bar menu shows ⌃⌥Space next to **Profile Switcher** as a key equivalent,
   while the README says Dockry sets no shortcuts itself. It only works while the menu is
   open, but it reads as a global shortcut.
8. Fresh-profile removal alert text: "This will remove all the data associated, you want
   to proceed?" (grammar), and the checkbox inverts the default action.
9. Folders in a profile can't be seen or reordered in the profile editor, only in the dock.
10. Fresh profile data folder names replace `/` with `-`, so profiles named `a/b` and `a-b`
    would share one data folder.
11. The profile switcher lays every profile out in one row with no scrolling; with many
    profiles it outgrows the screen. Digits pick only 1–9.

## Risks

12. **Private and undocumented APIs** (see `architecture.md` › System integrations). The
    Claude usage endpoint and Claude Code's OAuth client id are the most fragile; the
    widget also writes to another app's Keychain item.
13. **AppleScript built from strings.** `SpotifyPlayer.play(uri:)` strips `"` but not `\`.
    The URI comes from Spotify's API, so the input is trusted today.
14. **One `SpotifyPlayer` per dock.** With docks on several screens, each runs its own
    AppleScript polling while its popover is open, and each reads the track separately.
15. **Unbounded maps.** `WindowSpaceKeeper.recentlyAdjusted` only clears when the dock's
    reservation changes; `HotKeys.nextID` only grows. Small, but long sessions accumulate.

## Structure

16. **Logic with no tests lives in the app target.** `AppOpening.choose`, the
    `ProfileApps.isShown` / `show` rules, `activeProfileChanged`'s rename detection and
    `SystemDock`'s save/restore are pure decisions that could move to `DockryCore` and be
    unit tested. Most of the bugs above sit in exactly this untested layer.
17. **`AppDelegate` is the only place wiring happens**, through Combine sinks. Ordering
    matters (mode before enabled for profile apps) and is only documented in comments.
18. **Adding a widget touches five places** across both targets (see `architecture.md`
    › Widgets). `WidgetInfo`'s comment anticipates plugins; the closed `WidgetKind` enum
    doesn't.
19. **`DockView` recomputes `elements`** (and `AppCatalog` lookups) several times per body
    evaluation; it is re-evaluated on every pointer move over the dock.
