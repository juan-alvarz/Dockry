import AppKit
import Combine
import DockryCore

/// Dockry's settings, saved in its user defaults. While "Sync with Mac Dock settings" is on,
/// the dock follows the macOS Dock's own settings instead of the ones chosen here.
@MainActor
final class SettingsStore: ObservableObject {
    /// The settings chosen in Dockry's Settings window.
    @Published var own: DockSettings { didSet { save() } }
    @Published var syncsWithMacDock: Bool {
        didSet {
            defaults.set(syncsWithMacDock, forKey: Key.syncsWithMacDock)
            updateMacDockWatch()
        }
    }
    @Published private(set) var macDock: DockSettings
    /// Show running apps that aren't in the profile. The macOS Dock always does, so this
    /// isn't synced.
    @Published var showsUnpinnedApps: Bool {
        didSet { defaults.set(showsUnpinnedApps, forKey: Key.showsUnpinnedApps) }
    }

    /// Hide the macOS Dock while Dockry runs.
    @Published var hidesSystemDock: Bool {
        didSet { defaults.set(hidesSystemDock, forKey: Key.hidesSystemDock) }
    }

    /// Keep other apps' windows out of the dock's space, like the macOS Dock.
    @Published var keepsWindowsClear: Bool {
        didSet { defaults.set(keepsWindowsClear, forKey: Key.keepsWindowsClear) }
    }

    /// Give each profile its own open apps, hiding the other profiles' (see ProfileApps).
    @Published var separatesProfileApps: Bool {
        didSet { defaults.set(separatesProfileApps, forKey: Key.separatesProfileApps) }
    }

    /// With separate apps per profile, clicking an app in the dock that's open in another
    /// profile opens a window of its own here (⌘N) instead of moving the app over, and each
    /// window stays in its profile.
    @Published var opensNewAppInstances: Bool {
        didSet { defaults.set(opensNewAppInstances, forKey: Key.opensNewAppInstances) }
    }
    /// With that, a separate copy of the app per profile instead, with its own data for
    /// browsers and Electron apps.
    @Published var separatesAppData: Bool {
        didSet { defaults.set(separatesAppData, forKey: Key.separatesAppData) }
    }

    /// Fade a profile's wallpaper in when switching to it (see Wallpapers); off, it changes
    /// as soon as macOS shows it, and no pictures are decoded ahead of time.
    @Published var fadesWallpapers: Bool {
        didSet { defaults.set(fadesWallpapers, forKey: Key.fadesWallpapers) }
    }

    /// How the wallpaper comes in, and how long it takes (0.1 to 1 second).
    @Published var wallpaperTransition: WallpaperTransition {
        didSet { defaults.set(wallpaperTransition.rawValue, forKey: Key.wallpaperTransition) }
    }
    @Published var wallpaperTransitionDuration: Double {
        didSet { defaults.set(wallpaperTransitionDuration, forKey: Key.wallpaperTransitionDuration) }
    }

    /// Opens the profile switcher; none unless the user sets one.
    @Published var profileSwitcherShortcut: KeyShortcut? {
        didSet { defaults.set(profileSwitcherShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.profileSwitcherShortcut) }
    }

    /// What the dock uses right now.
    var dock: DockSettings { syncsWithMacDock ? macDock : own }

    private let defaults = UserDefaults.standard
    private var macDockTimer: Timer?

    private enum Key {
        static let syncsWithMacDock = "syncsWithMacDock"
        static let showsUnpinnedApps = "showsUnpinnedApps"
        static let hidesSystemDock = "hideSystemDock"
        static let keepsWindowsClear = "keepsWindowsClear"
        static let separatesProfileApps = "separatesProfileApps"
        static let opensNewAppInstances = "opensNewAppInstances"
        static let separatesAppData = "separatesAppData"
        static let fadesWallpapers = "fadesWallpapers"
        static let wallpaperTransition = "wallpaperTransition"
        static let wallpaperTransitionDuration = "wallpaperTransitionDuration"
        static let profileSwitcherShortcut = "profileSwitcherShortcut"
        static let position = "position"
        static let iconSize = "iconSize"
        static let magnifies = "magnifies"
        static let magnifiedSize = "magnifiedSize"
        static let autohides = "autohides"
        static let showsIndicators = "showsIndicators"
        static let animatesLaunch = "animatesLaunch"
    }

    init() {
        let defaults = UserDefaults.standard
        let fallback = DockSettings()
        own = DockSettings(
            position: defaults.string(forKey: Key.position).flatMap(DockPosition.init(rawValue:)) ?? fallback.position,
            iconSize: defaults.object(forKey: Key.iconSize) as? Double ?? fallback.iconSize,
            magnifies: defaults.object(forKey: Key.magnifies) as? Bool ?? fallback.magnifies,
            magnifiedSize: defaults.object(forKey: Key.magnifiedSize) as? Double ?? fallback.magnifiedSize,
            autohides: defaults.object(forKey: Key.autohides) as? Bool ?? fallback.autohides,
            showsIndicators: defaults.object(forKey: Key.showsIndicators) as? Bool ?? fallback.showsIndicators,
            animatesLaunch: defaults.object(forKey: Key.animatesLaunch) as? Bool ?? fallback.animatesLaunch)
        syncsWithMacDock = defaults.bool(forKey: Key.syncsWithMacDock)
        showsUnpinnedApps = defaults.object(forKey: Key.showsUnpinnedApps) as? Bool ?? true
        hidesSystemDock = defaults.bool(forKey: Key.hidesSystemDock)
        keepsWindowsClear = defaults.object(forKey: Key.keepsWindowsClear) as? Bool ?? true
        separatesProfileApps = defaults.bool(forKey: Key.separatesProfileApps)
        opensNewAppInstances = defaults.bool(forKey: Key.opensNewAppInstances)
        separatesAppData = defaults.bool(forKey: Key.separatesAppData)
        fadesWallpapers = defaults.object(forKey: Key.fadesWallpapers) as? Bool ?? true
        wallpaperTransition = defaults.string(forKey: Key.wallpaperTransition).flatMap(WallpaperTransition.init) ?? .fade
        wallpaperTransitionDuration = (defaults.object(forKey: Key.wallpaperTransitionDuration) as? Double ?? 0.3).clamped(to: 0.1...1)
        profileSwitcherShortcut = defaults.data(forKey: Key.profileSwitcherShortcut)
            .flatMap { try? JSONDecoder().decode(KeyShortcut.self, from: $0) }
        macDock = Self.readMacDock()
        updateMacDockWatch()
    }

    private func save() {
        defaults.set(own.position.rawValue, forKey: Key.position)
        defaults.set(own.iconSize, forKey: Key.iconSize)
        defaults.set(own.magnifies, forKey: Key.magnifies)
        defaults.set(own.magnifiedSize, forKey: Key.magnifiedSize)
        defaults.set(own.autohides, forKey: Key.autohides)
        defaults.set(own.showsIndicators, forKey: Key.showsIndicators)
        defaults.set(own.animatesLaunch, forKey: Key.animatesLaunch)
    }

    /// The Dock doesn't announce changes to its settings, so check every couple of seconds
    /// while syncing. Reading them is cheap.
    private func updateMacDockWatch() {
        macDockTimer?.invalidate()
        macDockTimer = nil
        guard syncsWithMacDock else { return }
        refreshMacDock()
        macDockTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshMacDock() }
        }
    }

    private func refreshMacDock() {
        let current = Self.readMacDock()
        if current != macDock {
            macDock = current
        }
    }

    private static func readMacDock() -> DockSettings {
        var values: [String: Any] = [:]
        for key in DockSettings.macDockPreferenceKeys {
            values[key] = SystemDock.userValue(forKey: key)
        }
        return DockSettings(macDockPreferences: values)
    }
}
