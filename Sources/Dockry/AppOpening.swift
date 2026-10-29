import AppKit
import DockryCore

/// What opening an app from the dock does in the active profile, also for
/// dockry://open/<bundle identifier>. With profiles keeping their apps apart, the app may be
/// open elsewhere, or the profile may run its own copies (Profile.freshApps).
@MainActor
enum AppOpening {
    /// Launches the app, or brings it forward and reopens a window, as the macOS Dock does.
    case launch(URL)
    /// Opens a copy of the app with a fresh profile's data, or with nil, the usual data.
    case newInstance(URL, bundleID: String, profile: String?)
    /// Opens a window of it on this desktop (ProfileApps.openWindow).
    case newWindow(NSRunningApplication)
    /// Brings forward this copy, among several of the app.
    case instance(NSRunningApplication)

    /// The app's running copies, and the one in the active profile.
    static func instances(of bundleID: String, runningApps: RunningApps, profileApps: ProfileApps)
        -> (here: NSRunningApplication?, all: [NSRunningApplication])
    {
        let all = runningApps.apps(withBundleID: bundleID)
        return (all.first(where: profileApps.isShown), all)
    }

    static func choose(
        url: URL, bundleID: String, here: NSRunningApplication?, instances: [NSRunningApplication],
        profileApps: ProfileApps, settings: SettingsStore, profile: Profile
    ) -> AppOpening {
        if let here {
            // Opening by URL could bring forward another profile's copy.
            return instances.count > 1 ? .instance(here) : .launch(url)
        }
        // A fresh profile always opens its own copy, with its own data.
        if profile.freshApps {
            return .newInstance(url, bundleID: bundleID, profile: profile.name)
        }
        let shared = instances.filter { !profileApps.isFreshCopy($0) }
        guard let other = shared.first else {
            // Only fresh profiles' copies are running: a copy with the usual data.
            return instances.isEmpty ? .launch(url) : .newInstance(url, bundleID: bundleID, profile: nil)
        }
        guard settings.separatesProfileApps, settings.opensNewAppInstances else { return .launch(url) }
        return .newWindow(other)
    }

    func perform(_ profileApps: ProfileApps) {
        switch self {
        case .launch(let url):
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        case .newInstance(let url, let bundleID, let profile):
            AppInstances.open(url, bundleID: bundleID, profile: profile)
        case .newWindow(let app):
            profileApps.openWindow(app)
        case .instance(let app):
            app.activate()
        }
    }
}
