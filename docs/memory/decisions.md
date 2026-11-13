# Decisions

One entry per decision, newest first: what was decided, why, and what was tried or
considered and rejected. See AGENTS.md › Project memory for when to add one.

## 2026-11-12 · An app that can't open a window here has its front window brought here
**Decision:** when New Window isn't found, or pressing it opens no window in the profile
within 2 s, the app's front window changes profile and comes on screen
(`ProfileApps.bringWindow`). New Window is ⌘N with "Window" in the title, then ⇧⌘N (VS Code,
Zed); ⌘N first, because ⇧⌘N is a private window in browsers.
**Why:** Spotify, Slack, Notes, Mail and any app in another language came forward with
every window off screen, and the keyboard went to a window nobody could see.
**Rejected:** switching to the app's profile (already rejected on 2026-11-02 for apps that
can open a window; kept the same here). Waiting a moment before bringing the window, in case
the app is about to open a document: every single-window app would lag.
**Not confirmed:** chosen during a code review, not by the user, and not checked on screen.

## 2026-11-12 · Parked windows are checked, not trusted
**Decision:** every look (`ProfileWindows.show`) checks what the records say. A window
is unparked only once it's read back on screen, and keeps its saved place until then. A
parked window found on screen is parked again. A window of the showing profile that's off
screen with no place saved is brought to the main screen. Dockry looks again when the macOS
desktop or the screens change, and forgets closed windows before each decision.
**Why:** the records drifted from the Mac: a failed move, an unplugged screen, a window
closed between two switches.
**Also:** windows park under a bottom corner of one screen (`WindowParking.spot`), not of
all the screens together, which can be on no screen.

## 2026-11-03 · Project memory instead of OpenSpec
**Decision:** OpenSpec (specs, change folders, notes, `/opsx` commands) is gone; what was
still worth keeping is in `docs/memory/`.
**Why:** the specs mostly restated what the code and tests show; decisions, quirks and
open bugs were buried among them. Project rules moved to AGENTS.md.

## 2026-11-02 · Profiles are Dockry's own workspaces, not macOS desktops
**Decision:** every window stays on its macOS desktop. Other profiles' windows are parked
just past the bottom-right corner of all screens together (one point stays on screen), as
AeroSpace does.
**Why:** no app can create macOS desktops, and switching desktops always slides.
**Rejected:** one macOS desktop (Space) per profile, built and deleted unmerged the same
day. It needed desktops made in Mission Control, "Switch to Desktop" shortcuts turned on,
two Desktop & Dock options off and windows moved by hand. A Mission Control button press
through Accessibility was tried to create desktops. The user found it awful: don't propose
Spaces again.

## 2026-11-02 · One mode, one record per window
**Decision:** one setting, "Give each profile its own windows", on by default, replaces
"Give each profile its own open apps" and "Open a new app instance". Each window is in the
profile active when it opened (`ProfileWindowRecords`, keyed by window number + pid).
**Why:** two modes doubled every rule, and fixes for one mode broke the other.

## 2026-11-02 · One rule for an app coming forward, however it came
**Decision:** `ProfileAppRules.activated` looks only at where the app's windows are.
- Its front window is here: nothing.
- It has a window here behind another profile's: that window comes forward.
- Its windows are all elsewhere: a new window here, through its New Window menu item
  (⌘N whose title contains "Window"), or its front window brought here (2026-11-12).
- It has no windows: nothing.

The dock, Raycast, ⌘Tab and links all get this answer.
**Why:** telling launchers apart from event order was guessed wrong. The first Raycast fix
assumed which app was in front before the opened one, and macOS reports the opposite order.
**Rejected:** launcher detection and timing windows (`launcherLeftAt` 1.5 s,
`switchedAt` 2 s); switching to the profile that holds the app's windows (the user chose
"a new window here"). The one timer left is Dockry's own: 3 s after pressing New Window.

## 2026-11-02 · No hidden apps (being revisited)
**Decision:** 0.3.0 hides no app; only windows move.
**Why:** hiding apps brought windows back as macOS brought the next app forward.
**Revisit:** Mission Control shows parked windows, and an app that refuses Accessibility
can only be hidden (known-issues, 2026-11-03). Plan: hide apps with no window in the active
profile, and park only apps with windows in several profiles. Hide after the keyboard has
moved to the new profile's front app, and unhide only what Dockry hid.

## 2026-11-02 · Wallpapers without memory
**Decision:** each switch, launch and screen change sets the active profile's picture, or
the macOS default, on every screen. Profiles without a picture were given the one showing
at the update, once (`wallpapersGivenToProfiles`).
**Why:** learning "the user's own picture" from the screens once saved another profile's
picture as the user's for good.
**Rejected:** remembering pictures Dockry set and filtering them out (still guessed from
screens; display ids change when a screen moves port).

## 2026-11-02 · Rules are pure code in DockryCore
**Decision:** what the dock shows, what a switch parks and what an app coming forward does
are decided in DockryCore, with one test per case the user hit. AppKit classes only read
macOS and apply the answer.
**Why:** rules inside untested AppKit glue broke on every fix. "Open a new app instance"
took five rounds.
**Limit:** tests prove the rule, not the Mac. See AGENTS.md: fixed only once checked in the
running app.

## 2026-11-02 · No speaker on the dock's profile button
**Decision:** sound marks profiles in the menu bar menu and the switcher only.
**Why:** a speaker on the active profile's button read as "this profile is playing".

## 2026-10-29 · Renames are explicit events
**Decision:** `ProfileLibrary.updateProfile` returns the final name, and
`ProfileStore.renamed` tells app owners, window records and fresh app data. The name field
commits on Return, losing focus or selecting another profile.
**Why:** a rename and a remove + add look the same in two library snapshots.
**Rejected:** diffing profile lists by position (wrong when a change also reorders).
**Better later:** stable profile ids (UUID, generated when missing) would remove every
rename handler.

## 2026-10-29 · App ownership by pid + launch time
**Decision:** `appOwners` saves pid, launch date and profile; an entry applies only to the
same process (launch times match within 1 s). The old `appProfiles` is deleted, not migrated.
**Why:** pids are reused after a Mac restart.
**Rejected:** dropping all ownership at login (loses it every time Dockry restarts).

## 2026-10-29 · The dock can't be moved by other apps
**Decision:** `DockPanel` refuses Accessibility's frame, size, minimize, full-screen, main
and focus setters, and snaps back to its frame on any move or resize.
**Rejected:** `isAccessibilityElement = false` (hides the dock from VoiceOver); a subrole
change (window managers differ in which subroles they skip).

## 2026-10-29 · Dividers show where they're placed
**Decision:** Add Divider is always enabled. A divider is dropped only when hidden things
alone separate it from an end or from another divider.
**Rejected:** greying out Add Divider where it would be hidden. In the installed app it
was greyed out where a divider would show, the cause was never found, and the user wanted
dividers anywhere.

## 2026-10-29 · Weather: Celsius or Fahrenheit, Celsius by default
**Rejected:** "System", even labelled "System (°F)". On many Macs `AppleTemperatureUnit`
isn't set, so it falls back to the region (°F for the US) and disagrees with the Weather
app's own setting.

## 2026-10-29 · One Default profile on first launch
**Decision:** Default, house symbol, Finder, nothing else.
**Rejected:** Work and Chill with widgets: a new install opened with Keychain, Location and
Automation prompts.

## 2026-10-29 · Release notes unwrapped by the script
**Decision:** `scripts/version.sh --notes` joins wrapped lines; CHANGELOG.md keeps them wrapped.
**Rejected:** unwrapped lines in CHANGELOG.md (read in editors and diffs too).

## 2026-10-29 · Magnified widgets are scaled, not re-laid out
**Decision:** a wrapper measures the widget and draws it with `scaleEffect`. A plateau in
`DockMagnification` makes a wide widget grow fully anywhere under the pointer.
**Rejected:** a scaled `DockMetrics` per widget (a `Layout` can't set an environment per
child, and popovers would be sized from scaled metrics).

## 2026-10-28 · No global shortcuts by default
**Why:** profile shortcuts clashed with Shortty. Shortcuts compare by key code and
modifiers only; when two are the same, only the first is registered.
