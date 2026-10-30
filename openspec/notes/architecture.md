# Dockry architecture notes

Working notes written while onboarding Dockry to OpenSpec (branch `dev--open-spec`).
They describe the code as it is; they are not a plan to change it. The behavior
contracts live in `openspec/specs/`; this file is the map behind them.

## Shape of the project

- Swift package, `swift-tools-version:5.9`, macOS 14+, no third-party dependencies.
- Three targets (`Package.swift`):
  - `DockryCore`: plain Foundation logic, no AppKit. Builds and tests on Linux too.
    Everything that can be unit tested lives here.
  - `Dockry`: the executable. AppKit + SwiftUI UI and every macOS integration
    (Accessibility, AppleScript, private frameworks, Keychain, Location Services).
  - `DockryCoreTests`: XCTest suite for `DockryCore` only. The app target has no tests.
- No Xcode project. `scripts/bundle.sh` wraps the SwiftPM binary in `build/Dockry.app`
  with `App/Info.plist`, the icon, and the version taken from the first `## <version>`
  heading of `CHANGELOG.md`.
- Menu bar app: activation policy `.accessory` (no Dock icon, no main menu except a
  hidden one that makes ⌘, ⌘W ⌘Q and the Edit shortcuts work in Settings).
- Bundle identifier `com.dockry.Dockry`. Up to 0.0.7 it was `io.github.juan-alvarz.Dockry`;
  `DockryMain` copies the old defaults domain on first launch under the new id.

## DockryCore (the model)

| File | What it owns |
|---|---|
| `Profile.swift` | `WidgetKind` enum and `Profile` (name, symbol, items, desktop, color, shortcut, opensAppsOnSwitch, wallpaper, freshApps). Lenient Codable. `Profile.defaults` = Work and Chill. |
| `ProfileLibrary.swift` | All profiles + active name. Invariants: ≥1 profile, unique names, active always valid. Add/duplicate/remove/rename/move/pin/unpin. |
| `ProfileFile.swift` | `~/Library/Application Support/Dockry/profiles.json`, pretty-printed, sorted keys, atomic write. Bad file → defaults + error, file untouched. |
| `DockItem.swift` | One dock item: `app(bundleID)`, `widget(kind)`, `folder(path)`, `runningApps`, `divider`. Serialized as one string each (`"divider"`, `"running-apps"`, `"widget:clock"`, `"folder:/path"`, else bundle id). |
| `DockLayout.swift` | Turns items + running apps into what the dock shows (`DockElement`), drop index/shift math for drag-to-reorder, items after a move. |
| `DockMagnification.swift` | Cosine-bump magnification; keeps the spot under the pointer fixed. |
| `DockPlacement.swift` | Which screens get a dock (bottom: all; left/right: the outermost screen). |
| `DockSettings.swift` | `DockPosition`, `DockSettings` (size 16–128, magnification, autohide, indicators, launch animation), reading the `com.apple.dock` prefs. `Comparable.clamped`. |
| `WindowFit.swift` | Frame math to keep windows out of the dock's strip. |
| `HexColor.swift` | `#RRGGBB` parse/normalize/format; WCAG luminance for light/dark text. |
| `KeyShortcut.swift` | Key code + modifiers; must have ⌃⌥ or ⌘ to be global; reads "Switch to Desktop N" from `com.apple.symbolichotkeys` (ids 118–126). |
| `MacUser.swift` | Parses `dscl -plist . -readall /Users`; keeps uid ≥ 501, not hidden, no `_` names; sorted by full name. |
| `MonthGrid.swift` | Calendar weeks for the date popover. |
| `WidgetInfo.swift` | Self-description of every widget (name, summary, details, symbol, tint, app, category, requirements, author). `WidgetCatalog.all` order. |
| `ClaudeUsage.swift` | Parses the undocumented `api.anthropic.com/api/oauth/usage`; reads/refreshes Claude Code's Keychain credentials. |
| `SpotifyTrack.swift` | Track from Spotify's distributed notification or AppleScript. |
| `SpotifyWebAPI.swift` | PKCE sign-in, token parse, search request/parse, `SpotifyPlayback` AppleScript. |
| `Weather.swift` | Open-Meteo request/parse; WMO code → SF Symbol and summary. |

### Profile invariants worth knowing

- `Profile.items` is normalized on every set: each app/widget/folder once, any number of
  dividers, exactly one `runningApps` (inserted after the last app if missing).
- `pinnedApps` / `widgets` setters keep everything else in place (removed go, kept ones
  take the old slots in new order, extras go after the last slot).
- Decoding is lenient: only `name` required; unknown widget names dropped; bad color or
  shortcut dropped, not fatal; old files with `pinnedApps` + `widgets` still load.
- Encoding omits `opensAppsOnSwitch` / `freshApps` when false.
- Renames to empty or to an existing name are ignored (other changes still apply).
- Duplicates are named `X Copy`, `X Copy 2`…, inserted right after, without the shortcut.
- New profiles named `X`, `X 2`, `X 3`…
- Removing the last profile is refused; removing the active one activates the first.

## Dockry (the app target)

### Startup and wiring

- `DockryMain` → migrate old defaults domain → `NSApplication` with `.accessory` policy.
- `AppDelegate.applicationDidFinishLaunching` owns and wires everything:
  `ProfileStore`, `SettingsStore`, `RunningApps`, `ProfileApps`, `DockController`,
  `MenuBarController`, `ProfileSwitcherPanel`. Wiring is Combine sinks on `@Published`
  values; there is no dependency container.
- Reactions to the active profile changing live in `activeProfileChanged(from:to:)`:
  show the profile's apps, switch wallpaper, open its pinned apps after the desktop switch.
  A rename is told apart from a switch by checking the old name still exists.
- Hot keys are re-registered whenever the library or the switcher shortcut changes.
- `SIGTERM` is turned into a normal `terminate` so `applicationWillTerminate` restores the
  system Dock and unparks windows.
- `application(_:open:)` handles `dockry://profile/<name>`, `dockry://open/<bundle id>` and
  the Spotify OAuth callback (`dockry://spotify-callback`).

### State and persistence

| Store | Where | What |
|---|---|---|
| `ProfileStore` | `~/Library/Application Support/Dockry/profiles.json` | The library. Every change saved at once. Not saved while the file failed to load (`loadError`). |
| `SettingsStore` | `UserDefaults` (`com.dockry.Dockry`) | Dock look (`position`, `iconSize`, `magnifies`, `magnifiedSize`, `autohides`, `showsIndicators`, `animatesLaunch`), `syncsWithMacDock`, `showsUnpinnedApps`, `hideSystemDock`, `keepsWindowsClear`, `separatesProfileApps`, `opensNewAppInstances`, `fadesWallpapers`, `wallpaperTransition`, `wallpaperTransitionDuration`, `profileSwitcherShortcut`. |
| `SystemDock` | `UserDefaults` | `systemDockHidden`, `systemDockOriginal.autohide`, `systemDockOriginal.autohide-delay`. |
| `ProfileApps` | `UserDefaults` `appOwners` (JSON `AppOwnership`) | pid + launch time → owning profile name. Older `appProfiles` (pid only) is deleted at launch. |
| `ProfileWindows` | `UserDefaults` `profileWindows` | window number → profile, pid, parked home frame. |
| `Wallpapers` | `UserDefaults` `ownWallpapers` | display id → the user's own picture path. |
| `FreshAppsBadge` | `UserDefaults` `freshAppsBadge` | SF Symbol for the fresh-profile badge. |
| `SpotifyAccount` | `UserDefaults` `spotifyClientID`, `spotifySignedIn`; file `spotify-refresh-token` (0600) | Spotify search sign-in. |
| `AppInstances` | `~/Library/Application Support/Dockry/App Data/<profile>/<bundle id>/` | Fresh profiles' browser/Electron data. |
| Claude usage | Keychain item `Claude Code-credentials` (owned by Claude Code) | Read, and written back after a token refresh. |

### Dock rendering

- `DockController` keeps one `DockPanel` per chosen screen (`DockPlacement`), keyed by
  display id, and re-lays out on screen changes and on any `SettingsStore` change.
- `DockPanel`: borderless non-activating `NSPanel` at the Dock window level, on all
  Spaces, never key. It spans the whole screen edge and is much thicker than the dock
  (`DockMetrics.panelThickness`) so magnification, labels and bounces fit; clicks on the
  clear parts pass through. Finder drops are handled in AppKit (`DockHostingView`), not SwiftUI.
- `DockView` (SwiftUI): `ViewThatFits` between the full row with magnification and a
  `ScrollView` without it. Elements come from `DockLayout.elements`. Drag-to-reorder is a
  `DragGesture` that offsets the dragged item and reorders the others live, then commits
  `DockLayout.items(afterMoving:)` to the active profile.
- `DockRowLayout` (SwiftUI `Layout`) places items with `DockMagnification`; its own size
  stays unmagnified.
- `DockPointer` (one per dock) + `PointerMonitor` (shared): global/local mouse monitors
  plus polling (8 Hz idle, 60 Hz over a dock). Drives magnification, hover labels,
  autohide reveal (400 ms linger), separator resize cursor. `BackgroundCursor` uses a
  private CGS property so the cursor can change while Dockry is in the background.
- `DockInteraction` counts popovers and drags that must keep an auto-hiding dock shown.
- `PopoverFocus` activates Dockry while a dock popover is open and gives focus back after.

### Apps and windows

- `RunningApps`: regular-policy apps, refreshed on `runningApplications` KVO and on
  activations (late-regular Electron apps). Dock id = bundle id, else bundle/executable path.
- `AppCatalog`: cached name/icon/url per bundle id; nil when not installed.
- `AppOpening`: decides what a click does: `launch`, `newInstance` (fresh profile copy),
  `newWindow` (⌘N in this profile), `instance` (activate this profile's copy).
- `AppQuitter`: presses the app's own ⌘Q menu item via Accessibility; falls back to the
  quit Apple event with an Automation permission check and an explanatory alert.
- `AppWindows` (shared): one `AXObserver` per regular app; minimized counts, window
  created/moved/resized callbacks, New Window menu item lookup, AX↔AppKit frame flips.
  Polls `AXIsProcessTrusted` every 2 s until granted.
- `WindowSpaceKeeper`: on window change, fits windows out of the dock strip
  (`WindowFit`), waiting for mouse-up during drags, and not re-fighting a window within 1 s.
- `ProfileApps`: the per-profile apps feature, modes `.apps` and `.windows`; fresh
  profiles are always separated. Hides/unhides apps (only those it hid), tracks sound via
  Core Audio process list (1.5 s poll) + private `responsibility_get_pid_responsible_for_pid`.
- `ProfileWindows`: per-window profile records keyed by `CGWindowID` (private
  `_AXUIElementGetWindow`); parks other profiles' windows at the bottom-right corner of the
  union of screens, one point visible.
- `AppInstances`: `createsNewApplicationInstance` launches; Gecko gets
  `--no-remote --profile <dir>`, Chromium/Electron `--user-data-dir=<dir>`; detection by
  `Resources/omni.ja` or a `* Framework.framework` in `Contents/Frameworks`.

### System integrations

| Feature | Mechanism | Permission |
|---|---|---|
| Hide macOS Dock | `com.apple.dock` `autohide` + `autohide-delay=1000`, `killall Dock` | none |
| Sync with Mac Dock | read `com.apple.dock` every 2 s while on | none |
| Desktop switching | read `com.apple.symbolichotkeys` 118–126, post CGEvents | Accessibility |
| Global shortcuts | Carbon `RegisterEventHotKey` | none |
| Window space / minimized / per-window profiles / quit via menu | AX API | Accessibility |
| Quit fallback | `kAEQuitApplication` | Automation per app |
| Fast User Switching | private `login.framework` `SACSwitchToUser`, `SACSwitchToLoginWindow`; `dscl` for users | none |
| Sound per profile | Core Audio process objects | none |
| Spotify now playing | distributed notification `com.spotify.client.PlaybackStateChanged` | none |
| Spotify control/art | `osascript` processes | Automation (Spotify) |
| Spotify search | Web API, PKCE | Spotify sign-in |
| Claude usage | Keychain + `api.anthropic.com/api/oauth/usage` (undocumented) | Keychain prompt |
| Weather | Core Location (3 km) + Open-Meteo | Location |
| Wallpapers | `NSWorkspace.setDesktopImageURL` + fade window at desktop level + 1 | none |
| Open at login | `SMAppService.mainApp` | user approval |

Private or undocumented APIs in use: `SACSwitchToUser`, `SACSwitchToLoginWindow`,
`_AXUIElementGetWindow`, `responsibility_get_pid_responsible_for_pid`,
`CGSSetConnectionProperty("SetsCursorInBackground")`, Anthropic's OAuth usage endpoint and
Claude Code's OAuth client id. Each has a fallback or degrades to doing nothing.

### Widgets

- `WidgetKind` (Core) is the closed list: `clock`, `date`, `spotify`, `users`, `claude`,
  `weather`. `WidgetInfo` describes each; `WidgetCatalog.all` is the Settings order
  (clock, date, spotify, claude, weather, users).
- `DockWidget` (app) pairs the info with a view factory and optional settings view;
  `DockWidget.widget(for:)` is a switch, so adding a widget touches `WidgetKind`,
  `WidgetInfo`, `WidgetCatalog.all`, `DockWidget.widget(for:)` and a new folder.
- Monitors (`ClaudeUsageMonitor`, `WeatherMonitor`) are singletons counting visible
  widgets; they fetch only while at least one is on screen. `SpotifyPlayer` is a
  `@StateObject` per widget instance (one per screen).
- `ScreenshotHook` reads launch-argument defaults (`openPopover`, `showSettings`,
  `showWidget`, `spotifyTest*`, `claudeUsageTestResponse`, `weatherTestLocation`,
  `logPointer`) so CI can stage screenshots without real accounts.

## Build, test, release

- `swift test` runs `DockryCoreTests` (≈100 test functions over 16 files). There are no
  tests for the app target; UI is checked by CI screenshots.
- `scripts/version.sh`: version = first `## x.y.z` heading of `CHANGELOG.md`; `--notes`
  prints that section.
- `scripts/bundle.sh [--universal]`: release build, `Info.plist`, `.icns`, version stamp,
  codesign with "Dockry Dev" if present else ad-hoc.
- `scripts/install.sh [--profile-only]`: `/Applications` or `~/Applications`, creates the
  signing certificate on first run.
- GitHub Actions are `workflow_dispatch` only: **Build & Screenshots** (build, test,
  screenshots, Fast User Switching check; commits PNGs on `dev`, publishes to the
  `screenshots` branch for `dev-*` branches) and **Release** (fails if the tag exists;
  tags `Dockry-<version>`, uploads dmg + zip).
- Branching: `dev` is the integration branch, features on `dev-*`, releases from `main`.
