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

    /// Adds a profile named `name`, or "name 2", "name 3"… if that's taken, and returns the
    /// name it got.
    @discardableResult
    public mutating func addProfile(named name: String) -> String {
        let names = Set(profiles.map(\.name))
        let unique = names.contains(name)
            ? (2...).lazy.map { "\(name) \($0)" }.first { !names.contains($0) }!
            : name
        profiles.append(Profile(name: unique))
        return unique
    }

    /// Removes a profile, unless it's the only one. Removing the active profile activates the first.
    public mutating func removeProfile(named name: String) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.name == name }
        if activeProfileName == name {
            activeProfileName = profiles[0].name
        }
    }

    /// Changes a profile. A rename to an empty name or to another profile's name is ignored
    /// (the other changes still apply), so names stay unique.
    public mutating func updateProfile(named name: String, _ change: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.name == name }) else { return }
        var updated = profiles[index]
        change(&updated)
        let newName = updated.name.trimmingCharacters(in: .whitespaces)
        if newName.isEmpty || (newName != name && profiles.contains(where: { $0.name == newName })) {
            updated.name = name
        } else {
            updated.name = newName
        }
        profiles[index] = updated
        if activeProfileName == name {
            activeProfileName = updated.name
        }
    }

    public mutating func moveProfile(named name: String, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.name == name }) else { return }
        let target = (index + offset).clamped(to: 0...(profiles.count - 1))
        profiles.insert(profiles.remove(at: index), at: target)
    }

    private mutating func updateActive(_ change: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.name == activeProfileName }) else { return }
        change(&profiles[index])
    }
}
