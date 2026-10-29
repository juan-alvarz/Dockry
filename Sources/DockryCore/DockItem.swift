import Foundation

/// One thing in a profile's dock, in the order the dock shows them.
public enum DockItem: Hashable {
    /// A pinned app, by bundle identifier.
    case app(String)
    case widget(WidgetKind)
    /// A folder, by path, shown as a stack of its contents like the macOS Dock's.
    case folder(String)
    /// Where the open apps that aren't in the profile go.
    case runningApps
    case divider
}

// As one string each in profiles.json, so the dock's order reads (and edits) as a plain list:
// "com.apple.Safari", "divider", "running-apps", "widget:clock", "folder:/Users/me/Downloads".
extension DockItem: Codable {
    private static let dividerName = "divider"
    private static let runningAppsName = "running-apps"
    private static let widgetPrefix = "widget:"
    private static let folderPrefix = "folder:"

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let item = DockItem(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown dock item \(text)"))
        }
        self = item
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    /// Nil for a widget Dockry doesn't have, such as a typo in the file.
    init?(_ text: String) {
        if text == Self.dividerName {
            self = .divider
        } else if text == Self.runningAppsName {
            self = .runningApps
        } else if text.hasPrefix(Self.widgetPrefix) {
            guard let kind = WidgetKind(rawValue: String(text.dropFirst(Self.widgetPrefix.count))) else { return nil }
            self = .widget(kind)
        } else if text.hasPrefix(Self.folderPrefix) {
            self = .folder(String(text.dropFirst(Self.folderPrefix.count)))
        } else {
            self = .app(text)
        }
    }

    var text: String {
        switch self {
        case .app(let bundleID): bundleID
        case .widget(let kind): Self.widgetPrefix + kind.rawValue
        case .folder(let path): Self.folderPrefix + path
        case .runningApps: Self.runningAppsName
        case .divider: Self.dividerName
        }
    }
}
