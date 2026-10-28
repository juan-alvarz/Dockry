import AppKit
import Carbon.HIToolbox
import DockryCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ProfileStore()
    private let runningApps = RunningApps()
    private let hotKeys = HotKeys()
    private var dockPanel: DockPanel?
    private var menuBar: MenuBarController?
    private var profileSwitcher: ProfileSwitcherPanel?
    private var terminationSignal: DispatchSourceSignal?

    private static let hidesSystemDockKey = "hideSystemDock"

    var hidesSystemDock: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hidesSystemDockKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.hidesSystemDockKey)
            applySystemDockSetting()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBar = MenuBarController(app: self)
        self.menuBar = menuBar

        let dock = DockView(store: store, runningApps: runningApps) {
            menuBar.popUpProfileMenu()
        }
        let panel = DockPanel(content: dock)
        panel.orderFrontRegardless()
        dockPanel = panel

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

        if hidesSystemDock {
            applySystemDockSetting()
        }
        quitGracefullyOnSIGTERM()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave the user without a Dock after Dockry quits.
        SystemDock.restore()
    }

    private func applySystemDockSetting() {
        hidesSystemDock ? SystemDock.hide() : SystemDock.restore()
        dockPanel?.coversSystemDock = hidesSystemDock
    }

    func showProfileSwitcher() {
        profileSwitcher?.showOrAdvance()
    }

    func activateProfile(named name: String) {
        store.activate(named: name)
        if store.active.opensAppsOnSwitch {
            openNotRunningApps(store.active.pinnedApps)
        }
        if let desktop = store.active.desktop {
            DesktopSwitcher.switchTo(desktop: desktop)
        }
    }

    /// Opens them without bringing them forward, so the app you're in keeps the keyboard.
    private func openNotRunningApps(_ bundleIDs: [String]) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        for bundleID in bundleIDs where runningApps.app(withBundleID: bundleID) == nil {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: configuration)
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
