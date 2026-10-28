import Foundation

/// Hides the macOS Dock by turning on auto-hide with a delay so long that it never shows.
/// The user's own settings are saved first and put back by `restore()`, including after a
/// crash: the saved values survive until a restore succeeds.
enum SystemDock {
    private static let dockDomain = "com.apple.dock" as CFString
    private static let changedKeys = ["autohide", "autohide-delay"]
    private static let hiddenFlag = "systemDockHidden"
    private static let savedValuePrefix = "systemDockOriginal."

    static func hide() {
        let defaults = UserDefaults.standard
        // If already hidden (e.g. Dockry crashed), the Dock's current values are ours, not the user's.
        if !defaults.bool(forKey: hiddenFlag) {
            for key in changedKeys {
                defaults.set(CFPreferencesCopyAppValue(key as CFString, dockDomain), forKey: savedValuePrefix + key)
            }
            defaults.set(true, forKey: hiddenFlag)
        }
        setDockValue(true, forKey: "autohide")
        setDockValue(1000.0, forKey: "autohide-delay")
        restartDock()
    }

    static func restore() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: hiddenFlag) else { return }
        for key in changedKeys {
            // A nil saved value means the key wasn't set, so this removes it again.
            setDockValue(defaults.object(forKey: savedValuePrefix + key), forKey: key)
            defaults.removeObject(forKey: savedValuePrefix + key)
        }
        defaults.set(false, forKey: hiddenFlag)
        restartDock()
    }

    /// One of the Dock's settings as the user set it: while Dockry hides the Dock, the
    /// values it changed are the saved originals, not its own.
    static func userValue(forKey key: String) -> Any? {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: hiddenFlag) && changedKeys.contains(key) {
            return defaults.object(forKey: savedValuePrefix + key)
        }
        CFPreferencesAppSynchronize(dockDomain)
        return CFPreferencesCopyAppValue(key as CFString, dockDomain)
    }

    private static func setDockValue(_ value: Any?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value.map { $0 as CFPropertyList }, dockDomain)
        CFPreferencesAppSynchronize(dockDomain)
    }

    /// The Dock only reads these settings at launch; launchd starts it again right away.
    private static func restartDock() {
        do {
            try Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
        } catch {
            NSLog("Dockry: couldn't restart the Dock: \(error)")
        }
    }
}
