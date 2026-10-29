import AppKit

/// Opens a profile's own copy of an app, for profiles with fresh apps (Profile.freshApps).
///
/// Most Mac apps run a second copy when asked. Browsers and Electron apps don't: the new
/// process hands over to the one running and quits, unless the copy keeps its data in a
/// folder of its own. Those get one per profile and app, which stays for next time, so the
/// profile's copy starts fresh the first time and keeps its own tabs and sign-ins after.
/// Other apps' copies share their data with the app's other copies.
@MainActor
enum AppInstances {
    private enum Engine {
        /// Firefox and browsers built on it, like Zen.
        case gecko
        /// Chrome, browsers built on Chromium, and Electron apps.
        case chromium
        case other
    }

    /// With no profile, a copy with the app's usual data, for when a fresh profile's copy of
    /// it is running.
    static func open(_ url: URL, bundleID: String, profile: String?) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = profile.map { arguments(for: url, bundleID: bundleID, profile: $0) } ?? []
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { NSLog("Dockry: couldn't open another copy of \(bundleID): \(error)") }
        }
    }

    private static func arguments(for url: URL, bundleID: String, profile: String) -> [String] {
        let engine = engine(of: url)
        guard engine != .other else { return [] }
        let folder = dataFolder(of: profile).appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return switch engine {
        case .gecko: ["--no-remote", "--profile", folder.path]
        case .chromium: ["--user-data-dir=\(folder.path)"]
        case .other: []
        }
    }

    /// Where a fresh profile's apps keep their data.
    static func dataFolder(of profile: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dockry/App Data", isDirectory: true)
            .appendingPathComponent(profile.replacingOccurrences(of: "/", with: "-"), isDirectory: true)
    }

    static func moveData(from oldName: String, to newName: String) {
        let old = dataFolder(of: oldName)
        guard FileManager.default.fileExists(atPath: old.path) else { return }
        do {
            try FileManager.default.moveItem(at: old, to: dataFolder(of: newName))
        } catch {
            NSLog("Dockry: couldn't move \(oldName)'s app data to \(newName): \(error)")
        }
    }

    /// Moves a fresh profile's app data to the Trash, so it can still be put back.
    static func trashData(of profile: String) {
        let folder = dataFolder(of: profile)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        do {
            try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
        } catch {
            NSLog("Dockry: couldn't move \(profile)'s app data to the Trash: \(error)")
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
