import AppKit
import Combine

/// The apps that would appear in the macOS Dock right now (regular apps, not agents or
/// background processes), kept up to date as apps launch, quit, and change kind.
@MainActor
final class RunningApps: ObservableObject {
    @Published private(set) var apps: [NSRunningApplication] = []

    private var subscription: AnyCancellable?
    /// Apps that aren't regular yet, watched in case they become one.
    private var policyWatches: [pid_t: NSKeyValueObservation] = [:]

    init() {
        // The launch notification alone missed apps: some (Electron apps, apps that start in
        // the menu bar) launch as background apps and only become regular apps later, which
        // posts nothing. runningApplications is observable and changes on every launch and quit.
        subscription = NSWorkspace.shared.publisher(for: \.runningApplications)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    /// The dock's IDs for the running apps, in launch order.
    var bundleIDs: [String] {
        apps.compactMap(Self.dockID)
    }

    func app(withBundleID bundleID: String) -> NSRunningApplication? {
        apps.first { Self.dockID(for: $0) == bundleID }
    }

    /// How the dock and profiles refer to an app: its bundle identifier, or for the few apps
    /// without one (some Java and command-line tools with windows), the path to the app.
    static func dockID(for app: NSRunningApplication) -> String? {
        app.bundleIdentifier ?? app.bundleURL?.path ?? app.executableURL?.path
    }

    private func refresh() {
        let running = NSWorkspace.shared.runningApplications
        apps = running.filter { $0.activationPolicy == .regular }

        let waiting = running.filter { $0.activationPolicy != .regular && !$0.isTerminated }
        let waitingPIDs = Set(waiting.map(\.processIdentifier))
        policyWatches = policyWatches.filter { waitingPIDs.contains($0.key) }
        for app in waiting where policyWatches[app.processIdentifier] == nil {
            policyWatches[app.processIdentifier] = app.observe(\.activationPolicy) { [weak self] _, _ in
                DispatchQueue.main.async { self?.refresh() }
            }
        }
    }
}
