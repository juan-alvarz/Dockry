import Foundation

/// Which profile each window is in, like the workspaces of AeroSpace or Linux desktops:
/// every window stays on one macOS desktop, and the windows of other profiles wait just off
/// screen ("parked"). Pure, so switching and restarting are unit tests
/// (ProfileWindowRecordsTests); the app's ProfileWindows moves the windows.
///
/// Windows are known by the window server's number, which lasts as long as the window, so
/// the records survive Dockry restarting. Saved as `[String: Record]`, as older versions did.
public struct ProfileWindowRecords: Codable, Equatable, Sendable {
    public struct Record: Codable, Equatable, Sendable {
        public var profile: String
        public var pid: Int32
        /// Where it was before it was parked; nil while it's on screen.
        public var home: CGRect?

        public init(profile: String, pid: Int32, home: CGRect? = nil) {
            self.profile = profile
            self.pid = pid
            self.home = home
        }
    }

    public private(set) var records: [UInt32: Record]

    public init(records: [UInt32: Record] = [:]) {
        self.records = records
    }

    public init(from decoder: Decoder) throws {
        let saved = try [String: Record](from: decoder)
        records = Dictionary(uniqueKeysWithValues: saved.compactMap { key, record in UInt32(key).map { ($0, record) } })
    }

    public func encode(to encoder: Encoder) throws {
        try Dictionary(uniqueKeysWithValues: records.map { (String($0.key), $0.value) }).encode(to: encoder)
    }

    /// The profiles the app has windows in.
    public func profiles(ofPID pid: Int32) -> Set<String> {
        Set(records.values.filter { $0.pid == pid }.map(\.profile))
    }

    public func profile(ofWindow number: UInt32) -> String? {
        records[number]?.profile
    }

    /// A window seen: kept if it's the same process's, else (new, or a number the window
    /// server gave to another process's window) it goes to `profile`.
    public mutating func see(_ number: UInt32, pid: Int32, newProfile profile: String) {
        if records[number]?.pid != pid {
            records[number] = Record(profile: profile, pid: pid)
        }
    }

    /// Forgets windows the window server no longer has.
    public mutating func keep(only existing: Set<UInt32>) {
        records = records.filter { existing.contains($0.key) }
    }

    public mutating func rename(_ profile: String, to newName: String) {
        for (number, record) in records where record.profile == profile {
            records[number]?.profile = newName
        }
    }

    /// Windows of profiles that no longer exist go to `profile`.
    public mutating func moveWindows(notIn profiles: Set<String>, to profile: String) {
        for (number, record) in records where !profiles.contains(record.profile) {
            records[number]?.profile = profile
        }
    }

    public mutating func parked(_ number: UInt32, home: CGRect) {
        records[number]?.home = home
    }

    public mutating func unparked(_ number: UInt32) {
        records[number]?.home = nil
    }

    /// What switching to `profile` moves, among the windows of `pids`: the profile's parked
    /// windows come back, and the others' go away. With `separatesAll` off, only windows a
    /// fresh profile is involved in go away: they're always kept apart.
    public func switchPlan(to profile: String, pids: Set<Int32>, separatesAll: Bool, freshProfiles: Set<String>)
        -> (park: [UInt32], unpark: [UInt32])
    {
        var park: [UInt32] = []
        var unpark: [UInt32] = []
        for (number, record) in records.sorted(by: { $0.key < $1.key }) where pids.contains(record.pid) {
            let away = record.profile != profile
                && (separatesAll || freshProfiles.contains(record.profile) || freshProfiles.contains(profile))
            if away && record.home == nil {
                park.append(number)
            } else if !away && record.home != nil {
                unpark.append(number)
            }
        }
        return (park, unpark)
    }

    /// Every parked window, for when Dockry quits or stops keeping windows apart.
    public var parkedWindows: [UInt32] {
        records.filter { $0.value.home != nil }.map(\.key).sorted()
    }
}
