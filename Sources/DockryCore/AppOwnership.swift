import Foundation

/// Which profile each open app belongs to, as saved between Dockry's launches. A process is
/// known by its id and launch time together: ids are reused (after the Mac restarts, say),
/// so an id alone could give an unrelated app another app's profile.
public struct AppOwnership: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public var pid: Int32
        public var launchedAt: Date?
        public var profile: String

        public init(pid: Int32, launchedAt: Date?, profile: String) {
            self.pid = pid
            self.launchedAt = launchedAt
            self.profile = profile
        }
    }

    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// The profile saved for this very process, if any. Launch times match within a second,
    /// as saving rounds them; a process without one matches only an entry saved without one.
    public func profile(forPID pid: Int32, launchedAt: Date?) -> String? {
        entries.first { entry in
            guard entry.pid == pid else { return false }
            switch (entry.launchedAt, launchedAt) {
            case (nil, nil): return true
            case let (saved?, actual?): return abs(saved.timeIntervalSince(actual)) < 1
            default: return false
            }
        }?.profile
    }
}
