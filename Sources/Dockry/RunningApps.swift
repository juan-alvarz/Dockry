import AppKit
import Combine

/// The apps that would appear in the macOS Dock right now (regular apps, not agents or
/// background processes), kept up to date as apps launch and quit.
@MainActor
final class RunningApps: ObservableObject {
    @Published private(set) var apps: [NSRunningApplication] = []

    private var subscription: AnyCancellable?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        subscription = Publishers.Merge(
            center.publisher(for: NSWorkspace.didLaunchApplicationNotification),
            center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
        )
        .sink { [weak self] _ in self?.refresh() }
        refresh()
    }

    var bundleIDs: [String] {
        apps.compactMap(\.bundleIdentifier)
    }

    func app(withBundleID bundleID: String) -> NSRunningApplication? {
        apps.first { $0.bundleIdentifier == bundleID }
    }

    private func refresh() {
        apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }
}
