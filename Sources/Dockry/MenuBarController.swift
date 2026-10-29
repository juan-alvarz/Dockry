import AppKit
import Combine
import DockryCore

/// The menu bar item: switches profiles and holds Dockry's settings.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private unowned let app: AppDelegate
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var symbolSubscription: AnyCancellable?

    init(app: AppDelegate) {
        self.app = app
        super.init()
        let menu = NSMenu()
        menu.delegate = self  // rebuilt each time it opens, see menuNeedsUpdate
        statusItem.menu = menu
        symbolSubscription = app.store.$library
            .map(\.active.symbol)
            .removeDuplicates()
            .sink { [weak self] symbol in
                self?.statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Dockry")
            }
    }

    /// The profile list on its own, shown by the profile button in the dock.
    func popUpProfileMenu() {
        let menu = NSMenu()
        profileItems().forEach(menu.addItem)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let app = self.app
        menu.removeAllItems()
        menu.addItem(.sectionHeader(title: "Profiles"))
        profileItems().forEach(menu.addItem)
        let switcher = ActionMenuItem("Profile Switcher", key: " ") { app.showProfileSwitcher() }
        switcher.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(switcher)

        menu.addItem(.separator())
        menu.addItem(switchUserItem())
        let hideDock = ActionMenuItem("Hide macOS Dock") { app.settings.hidesSystemDock.toggle() }
        hideDock.state = app.settings.hidesSystemDock ? .on : .off
        menu.addItem(hideDock)
        if let item = desktopSwitchingItem() {
            menu.addItem(item)
        }

        menu.addItem(.separator())
        if app.store.loadError != nil {
            let warning = ActionMenuItem("profiles.json has an error; changes aren’t saved until it’s fixed") {
                SettingsWindow.show(tab: .profiles)
            }
            warning.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(warning)
        }
        menu.addItem(ActionMenuItem("Edit Profiles…") { SettingsWindow.show(tab: .profiles) })
        menu.addItem(ActionMenuItem("Settings…", key: ",") { SettingsWindow.show() })

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Quit Dockry", key: "q") { NSApp.terminate(nil) })
    }

    private func profileItems() -> [NSMenuItem] {
        let app = self.app
        let playing = app.profileApps.playingProfiles
        return app.store.library.profiles.map { profile in
            // Shows the profile's global shortcut, if it has one with a plain key.
            let key = profile.shortcut?.key.flatMap { $0.count == 1 ? $0.lowercased() : nil } ?? ""
            let item = ActionMenuItem(profile.name, key: key) {
                app.activateProfile(named: profile.name)
            }
            item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(profile.shortcut?.modifiers ?? 0))
            item.image = NSImage(systemSymbolName: profile.symbol, accessibilityDescription: nil)
            item.state = profile.name == app.store.active.name ? .on : .off
            if playing.contains(profile.name) {
                let title = NSMutableAttributedString(string: profile.name + "  ")
                let speaker = NSTextAttachment()
                speaker.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Playing sound")
                title.append(NSAttributedString(attachment: speaker))
                item.attributedTitle = title
            }
            return item
        }
    }

    /// Fast User Switching, like the user menu in Control Center.
    private func switchUserItem() -> NSMenuItem {
        let submenu = NSMenu()
        for user in MacUsers.shared.others {
            submenu.addItem(ActionMenuItem(user.fullName) { UserSwitching.switchTo(user) })
        }
        if !submenu.items.isEmpty {
            submenu.addItem(.separator())
        }
        submenu.addItem(ActionMenuItem("Login Window…") { UserSwitching.showLoginWindow() })
        let item = NSMenuItem(title: "Switch User", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "person.2", accessibilityDescription: nil)
        item.submenu = submenu
        return item
    }

    /// Explains what's missing when a profile has a desktop that Dockry can't switch to yet.
    private func desktopSwitchingItem() -> NSMenuItem? {
        for desktop in app.store.library.profiles.compactMap(\.desktop) {
            switch DesktopSwitcher.status(for: desktop) {
            case .ready:
                continue
            case .needsAccessibility:
                return ActionMenuItem("Allow Desktop Switching…") { DesktopSwitcher.requestAccessibility() }
            case .shortcutOff:
                return ActionMenuItem("Turn On “Switch to Desktop \(desktop)” Shortcut…") {
                    DesktopSwitcher.openKeyboardShortcutsSettings()
                }
            }
        }
        return nil
    }
}

/// A menu item that runs a closure, instead of the target/selector pair.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}
