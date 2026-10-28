import Foundation

/// A person's account on this Mac, for Fast User Switching.
public struct MacUser: Equatable, Identifiable {
    /// The short (login) name.
    public let name: String
    public let fullName: String
    public let uid: UInt32
    /// The account picture, if the account has one.
    public let picturePath: String?

    public var id: UInt32 { uid }

    public init(name: String, fullName: String, uid: UInt32, picturePath: String? = nil) {
        self.name = name
        self.fullName = fullName
        self.uid = uid
        self.picturePath = picturePath
    }

    /// The command whose output `parseDirectoryListing` reads.
    public static let directoryListingCommand = [
        "/usr/bin/dscl", "-plist", ".", "-readall", "/Users",
        "RecordName", "RealName", "UniqueID", "Picture", "IsHidden",
    ]

    /// People's accounts from `directoryListingCommand`'s output, sorted by full name. Leaves
    /// out system accounts: UIDs below 501 (where macOS starts numbering people), hidden
    /// accounts, and names starting with "_".
    public static func parseDirectoryListing(_ data: Data) -> [MacUser] {
        guard let records = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: [String]]]
        else { return [] }
        return records.compactMap { record -> MacUser? in
            func first(_ attribute: String) -> String? { record["dsAttrTypeStandard:" + attribute]?.first }
            guard let name = first("RecordName"), !name.hasPrefix("_"),
                  let uid = first("UniqueID").flatMap({ UInt32($0) }), uid >= 501,
                  !["1", "yes", "true"].contains(first("IsHidden")?.lowercased() ?? "")
            else { return nil }
            return MacUser(name: name, fullName: first("RealName") ?? name, uid: uid, picturePath: first("Picture"))
        }
        .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    /// Up to two letters for an avatar without a picture: "Alex Rivera" → "AR".
    public var initials: String {
        String(fullName.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }
}
