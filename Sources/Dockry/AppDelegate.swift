import AppKit
import Carbon.HIToolbox
import Combine
import DockryCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ProfileStore()
    let settings = SettingsStore()
    private let runningApps = RunningApps()
    private let hotKeys = HotKeys()
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

        let (store, runningApps, settings) = (store, runningApps, settings)
        let actions = DockActions(
            showProfileMenu: { menuBar.popUpProfileMenu() },
            openSettings: { SettingsWindow.show() })
        docks = DockController(settings: settings) { pointer in
            DockView(store: store, runningApps: runningApps, settings: settings, pointer: pointer, actions: actions)
        }

        let switcher = ProfileSwitcherPanel(store: store) { [weak self] in self?.activateProfile(named: $0) }
        profileSwitcher = switcher
        hotKeys.register(keyCode: UInt16(kVK_Space), modifiers: controlKey | optionKey) {
            switcher.showOrAdvance()
        }
        // ⌃⌥1 … ⌃⌥9 activate the first nine profiles.
        for digit in 1...9 {
            guard let keyCode = KeyShortcut.keyCode(forDigit: digit) else { continue }
            hotKeys.register(keyCode: keyCode, modifiers: controlKey | optionKey) { [weak self] in
                self?.activateProfile(at: digit - 1)
            }
        }

        settings.$hidesSystemDock
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] in self?.applySystemDockSetting(hides: $0) }
            .store(in: &subscriptions)
        if settings.hidesSystemDock {
            applySystemDockSetting(hides: true)
        }
        quitGracefullyOnSIGTERM()

        if let tab = ScreenshotHook.settingsTab {
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
        let previous = store.active.name
        store.activate(named: name)
        let switched = store.active.name == name && name != previous
        if let desktop = store.active.desktop {
            DesktopSwitcher.switchTo(desktop: desktop)
        }
        if switched && store.active.opensAppsOnSwitch {
            // After the desktop switch has started, so their windows open on the new desktop.
            let apps = store.active.pinnedApps
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Self.openIfNotRunning(apps) }
        }
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

    private func activateProfile(at index: Int) {
        let profiles = store.library.profiles
        guard profiles.indices.contains(index) else { return }
        activateProfile(named: profiles[index].name)
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
