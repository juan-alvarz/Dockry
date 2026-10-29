import AppKit
import Combine

/// The apps that would appear in the macOS Dock right now (regular apps, not agents or
/// background processes), kept up to date as apps launch, quit, and change kind.
@MainActor
final class RunningApps: ObservableObject {
    @Published private(set) var apps: [NSRunningApplication] = []

    private var subscription: AnyCancellable?

    init() {
        // The launch notification alone missed apps: some (Electron apps, apps that start in
        // the menu bar) launch as background apps and only become regular apps later, which
        // posts nothing. runningApplications is observable and changes on every launch and
        // quit, and an app that turns regular activates when it shows its first window.
        // (Not KVO on each app's activationPolicy: with short-lived helper processes, like a
        // screenshot app's, AppKit sent those changes to freed observers and crashed Dockry.)
        subscription = Publishers.Merge(
            NSWorkspace.shared.publisher(for: \.runningApplications).map { _ in () },
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification).map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.refresh() }
    }

    /// The dock's IDs for the running apps, in launch order.
    var bundleIDs: [String] {
        apps.compactMap(Self.dockID)
    }

    func app(withBundleID bundleID: String) -> NSRunningApplication? {
        apps.first { Self.dockID(for: $0) == bundleID }
    }

    /// Every running copy of the app; more than one when profiles open their own.
    func apps(withBundleID bundleID: String) -> [NSRunningApplication] {
        apps.filter { Self.dockID(for: $0) == bundleID }
    }

    /// How the dock and profiles refer to an app: its bundle identifier, or for the few apps
    /// without one (some Java and command-line tools with windows), the path to the app.
    static func dockID(for app: NSRunningApplication) -> String? {
        app.bundleIdentifier ?? app.bundleURL?.path ?? app.executableURL?.path
    }

    private func refresh() {
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        // Activations are frequent; only publish when the set of apps changed.
        if regular.map(\.processIdentifier) != apps.map(\.processIdentifier) {
            apps = regular
        }
    }
}
