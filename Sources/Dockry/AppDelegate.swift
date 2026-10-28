import AppKit
import Carbon.HIToolbox
import Combine
import DockryCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ProfileStore()
    let settings = SettingsStore()
    private let runningApps = RunningApps()
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
