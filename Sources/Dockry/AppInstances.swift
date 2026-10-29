import AppKit

/// Opens a separate copy of an app for a profile, while another profile has the app open.
///
/// Most Mac apps run a second copy when asked. Browsers and Electron apps don't: the new
/// process hands over to the one running and quits, unless the copy keeps its data in a
/// folder of its own. Those get one per profile and app, which stays for next time, so the
/// profile's copy starts fresh the first time and keeps its own tabs and sign-ins after.
@MainActor
enum AppInstances {
    private enum Engine {
        /// Firefox and browsers built on it, like Zen.
        case gecko
        /// Chrome, browsers built on Chromium, and Electron apps.
        case chromium
        case other
    }

    static func open(_ url: URL, bundleID: String, profile: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = arguments(for: url, bundleID: bundleID, profile: profile)
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { NSLog("Dockry: couldn't open another copy of \(bundleID): \(error)") }
        }
    }

    private static func arguments(for url: URL, bundleID: String, profile: String) -> [String] {
        let engine = engine(of: url)
        guard engine != .other else { return [] }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dockry/App Data", isDirectory: true)
            .appendingPathComponent(profile.replacingOccurrences(of: "/", with: "-"), isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return switch engine {
        case .gecko: ["--no-remote", "--profile", folder.path]
        case .chromium: ["--user-data-dir=\(folder.path)"]
        case .other: []
        }
    }

    private static func engine(of url: URL) -> Engine {
        let contents = url.appendingPathComponent("Contents")
        let files = FileManager.default
        if files.fileExists(atPath: contents.appendingPathComponent("Resources/omni.ja").path) {
            return .gecko
        }
        // "Google Chrome Framework", "Brave Browser Framework", "Electron Framework"…
        let frameworks = (try? files.contentsOfDirectory(atPath: contents.appendingPathComponent("Frameworks").path)) ?? []
        return frameworks.contains { $0.hasSuffix(" Framework.framework") } ? .chromium : .other
    }
}
