import AppKit

@main
enum DockryMain {
    @MainActor
    static func main() {
        moveSettingsFromOldIdentifier()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu bar app: no Dock icon of its own and no main menu.
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    /// Up to 0.0.7 Dockry was io.github.juan-alvarz.Dockry, and its settings are saved under that name.
    private static func moveSettingsFromOldIdentifier() {
        let defaults = UserDefaults.standard
        guard let id = Bundle.main.bundleIdentifier, defaults.persistentDomain(forName: id) == nil,
              let old = defaults.persistentDomain(forName: "io.github.juan-alvarz.Dockry")
        else { return }
        defaults.setPersistentDomain(old, forName: id)
    }
}
