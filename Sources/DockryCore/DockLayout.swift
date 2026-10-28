public struct DockEntry: Equatable, Identifiable {
    public let bundleID: String
    public let isPinned: Bool
    public let isRunning: Bool

    public var id: String { bundleID }
}

public enum DockLayout {
    /// The dock's two app sections: the profile's pinned apps in the order the profile lists
    /// them, then the apps that are running but not pinned, in launch order. Each app appears once.
    public static func sections(
        pinned: [String], running: [String]
    ) -> (pinned: [DockEntry], running: [DockEntry]) {
        let runningSet = Set(running)
        var seen = Set<String>()
        let pinnedEntries = pinned
            .filter { seen.insert($0).inserted }
            .map { DockEntry(bundleID: $0, isPinned: true, isRunning: runningSet.contains($0)) }
        let runningEntries = running
            .filter { seen.insert($0).inserted }
            .map { DockEntry(bundleID: $0, isPinned: false, isRunning: true) }
        return (pinnedEntries, runningEntries)
    }
}
