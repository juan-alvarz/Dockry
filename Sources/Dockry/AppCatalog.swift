import AppKit

/// Names, icons and locations of apps by bundle identifier. Cached because LaunchServices
/// lookups aren't free and the dock redraws whenever an app launches or quits.
@MainActor
enum AppCatalog {
    struct App {
        let name: String
        let icon: NSImage
        let url: URL
    }

    private static var cache: [String: App] = [:]

    /// Nil when the app isn't installed. A running instance is preferred because it also
    /// covers apps LaunchServices doesn't know about, like ones launched from a build folder.
    static func app(bundleID: String, running: NSRunningApplication?) -> App? {
        if let cached = cache[bundleID] {
            return cached
        }
        guard let url = running?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        let app = App(
            name: running?.localizedName ?? FileManager.default.displayName(atPath: url.path),
            icon: NSWorkspace.shared.icon(forFile: url.path),
            url: url)
        cache[bundleID] = app
        return app
    }
}
