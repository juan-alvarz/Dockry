import Foundation

/// All profiles plus which one is active. Always holds at least one profile, and the active
/// name always refers to one of them.
public struct ProfileLibrary: Codable, Equatable {
    public private(set) var profiles: [Profile]
    public private(set) var activeProfileName: String

    /// Empty `profiles` falls back to the defaults; duplicate names keep the first profile;
    /// an unknown `activeProfileName` activates the first profile.
    public init(profiles: [Profile] = Profile.defaults, activeProfileName: String? = nil) {
        var seenNames = Set<String>()
        let unique = profiles.filter { seenNames.insert($0.name).inserted }
        self.profiles = unique.isEmpty ? Profile.defaults : unique
        self.activeProfileName = self.profiles[0].name
        if let activeProfileName {
            activate(named: activeProfileName)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            profiles: try container.decode([Profile].self, forKey: .profiles),
            activeProfileName: try container.decodeIfPresent(String.self, forKey: .activeProfileName)
        )
    }

    public var active: Profile {
        profiles.first { $0.name == activeProfileName } ?? profiles[0]
    }

    public mutating func activate(named name: String) {
        if profiles.contains(where: { $0.name == name }) {
            activeProfileName = name
        }
    }

    /// Pins an app to the end of the active profile's dock, unless it's already there.
    public mutating func pin(_ bundleID: String) {
        updateActive { profile in
            if !profile.pinnedApps.contains(bundleID) {
                profile.pinnedApps.append(bundleID)
            }
        }
    }

    public mutating func unpin(_ bundleID: String) {
        updateActive { $0.pinnedApps.removeAll { $0 == bundleID } }
    }

    /// Puts the active profile's pinned apps in `order`, the order the dock shows after a
    /// drag. Pinned apps it leaves out (ones the dock doesn't show, like an app that isn't
    /// installed) go after it, in their old order; apps in it that aren't pinned are ignored.
    public mutating func reorderPins(_ order: [String]) {
        updateActive { profile in
            let pinned = profile.pinnedApps
            let shown = order.filter { pinned.contains($0) }
            profile.pinnedApps = shown + pinned.filter { !shown.contains($0) }
        }
    }

    private mutating func updateActive(_ change: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.name == activeProfileName }) else { return }
        change(&profiles[index])
    }
}
