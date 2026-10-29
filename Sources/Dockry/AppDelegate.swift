import AppKit
import Carbon.HIToolbox
import Combine
import DockryCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ProfileStore()
    let settings = SettingsStore()
    private let runningApps = RunningApps()
    private(set) lazy var profileApps = ProfileApps(store: store)
    private var docks: DockController?
    private var menuBar: MenuBarController?
    private var profileSwitcher: ProfileSwitcherPanel?
    private var terminationSignal: DispatchSourceSignal?
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsWindow.configure(store: store, settings: settings)
        installMainMenu()
        let menuBar = MenuBarController(app: self)
        self.menuBar = menuBar

        let (store, runningApps, settings, profileApps) = (store, runningApps, settings, profileApps)
        let actions = DockActions(
            showProfileMenu: { menuBar.popUpProfileMenu() },
            openSettings: { SettingsWindow.show() })
        docks = DockController(settings: settings) { pointer in
            DockView(
                store: store, runningApps: runningApps, profileApps: profileApps, settings: settings, pointer: pointer,
                actions: actions)
        }

        settings.$separatesProfileApps
            .sink { profileApps.isEnabled = $0 }
            .store(in: &subscriptions)
        // After the change is stored, and with the profile it changed from.
        store.$library
            .map(\.active)
            .receive(on: RunLoop.main)
            .scan((Profile?.none, Profile?.none)) { ($0.1, $1) }
            .sink { [weak self] previous, active in
                if let active { self?.activeProfileChanged(from: previous, to: active) }
            }
            .store(in: &subscriptions)
        store.$library
            .map { $0.profiles.compactMap(\.wallpaper) }
            .removeDuplicates()
            .combineLatest(settings.$fadesWallpapers)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, fades in
                Wallpapers.fadesIn = fades
                self.map { Wallpapers.prepare($0.store.library.profiles) }
            }
            .store(in: &subscriptions)

        let switcher = ProfileSwitcherPanel(store: store, profileApps: profileApps) { [weak self] in self?.activateProfile(named: $0) }
        profileSwitcher = switcher
        // The shortcuts the user set: one for the switcher, and one per profile.
        store.$library.combineLatest(settings.$profileSwitcherShortcut)
            .sink { [weak self] library, switcherShortcut in
                var shortcuts: [(KeyShortcut, () -> Void)] = library.profiles.compactMap { profile in
                    profile.shortcut.map { ($0, { self?.activateProfile(named: profile.name) }) }
                }
                if let switcherShortcut {
                    shortcuts.append((switcherShortcut, { switcher.showOrAdvance(holding: switcherShortcut) }))
                }
                HotKeys.shared.set(shortcuts)
            }
            .store(in: &subscriptions)

        settings.$hidesSystemDock
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] in self?.applySystemDockSetting(hides: $0) }
            .store(in: &subscriptions)
        if settings.hidesSystemDock {
            applySystemDockSetting(hides: true)
        }
        quitGracefullyOnSIGTERM()

        if let widget = ScreenshotHook.settingsWidget {
            SettingsWindow.show(widget: widget)
        } else if let tab = ScreenshotHook.settingsTab {
            SettingsWindow.show(tab: SettingsTab(rawValue: tab))
        }
    }

    /// Spotify's sign-in comes back as a dockry:// URL.
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(SpotifyAccount.shared.handleCallback)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave the user without a Dock after Dockry quits.
        SystemDock.restore()
    }

    private func applySystemDockSetting(hides: Bool) {
        hides ? SystemDock.hide() : SystemDock.restore()
        docks?.coversSystemDock = hides
    }

    /// Dockry has no menu bar of its own, but the Settings window's text fields need the Edit
    /// menu's shortcuts (⌘V to paste, …), which only work through the main menu.
    private func installMainMenu() {
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit Dockry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let mainMenu = NSMenu()
        for submenu in [appMenu, editMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettings() {
        SettingsWindow.show()
    }

    func showProfileSwitcher() {
        profileSwitcher?.showOrAdvance()
    }

    func activateProfile(named name: String) {
        store.activate(named: name)
        if let desktop = store.active.desktop {
            DesktopSwitcher.switchTo(desktop: desktop)
        }
    }

    /// What follows the active profile, however it was switched: its apps, its wallpaper,
    /// and opening its pinned apps if it asks for that.
    private func activeProfileChanged(from previous: Profile?, to active: Profile) {
        // Not a rename: the profile it was is still there.
        let switched = previous.map { previous in
            previous.name != active.name && store.library.profiles.contains { $0.name == previous.name }
        } ?? false
        guard switched || previous?.wallpaper != active.wallpaper else { return }
        if switched {
            profileApps.show(active.name)
        }
        // At once, during the desktop switch: macOS shows one desktop picture on every desktop.
        Wallpapers.switched(from: previous, to: active)
        // Once on the profile's desktop, so their windows open there.
        if switched && active.opensAppsOnSwitch {
            afterDesktopSwitch(active.desktop != nil) { Self.openIfNotRunning(active.pinnedApps) }
        }
    }

    private func afterDesktopSwitch(_ isSwitching: Bool, _ action: @escaping () -> Void) {
        guard isSwitching else { return action() }
        var observer: NSObjectProtocol?
        var done = false
        let finish = {
            guard !done else { return }
            done = true
            observer.map(NSWorkspace.shared.notificationCenter.removeObserver)
            action()
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { finish() } }
        // Already on that desktop: nothing changes, so don't wait for long.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { finish() }
    }

    /// Opens the apps without bringing them forward, so the app you're in keeps the keyboard.
    private static func openIfNotRunning(_ bundleIDs: [String]) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        for bundleID in bundleIDs where NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSLog("Dockry: can't open \(bundleID); it isn't installed")
                continue
            }
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error { NSLog("Dockry: couldn't open \(bundleID): \(error)") }
            }
        }
    }

    /// `killall Dockry` and logout send SIGTERM, which would otherwise end the process
    /// without `applicationWillTerminate`, leaving the system Dock hidden.
    private func quitGracefullyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        terminationSignal = source
    }
}
