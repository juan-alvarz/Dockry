import Foundation

public enum WidgetKind: String, Codable {
    case clock
    case date
    case spotify
    /// The Mac's other user accounts, for Fast User Switching.
    case users
    /// How much of the Claude plan's usage limits are used.
    case claude
}

/// A context like "Work" or "Chill": the apps pinned to the dock, the widgets shown next to
/// them, and the macOS desktop (Space) to jump to when the profile is activated.
public struct Profile: Codable, Equatable {
    public static let defaultSymbol = "square.grid.2x2.fill"

    /// Profiles are identified by name, which keeps the JSON file easy to edit by hand.
    public var name: String
    /// SF Symbol shown for the profile in the dock and the menu bar.
    public var symbol: String
    /// Bundle identifiers, in dock order.
    public var pinnedApps: [String]
    public var widgets: [WidgetKind]
    /// Desktop number (1–9) to switch to on activation; nil stays on the current desktop.
    public var desktop: Int?

    public init(
        name: String,
        symbol: String = Profile.defaultSymbol,
        pinnedApps: [String] = [],
        widgets: [WidgetKind] = [],
        desktop: Int? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.pinnedApps = pinnedApps
        self.widgets = widgets
        self.desktop = desktop
    }

    // Lenient decoding so a hand-written profile only needs a name, and a typo in a widget
    // name drops that widget instead of making the whole file unreadable.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let widgetNames = try container.decodeIfPresent([String].self, forKey: .widgets) ?? []
        self.init(
            name: try container.decode(String.self, forKey: .name),
            symbol: try container.decodeIfPresent(String.self, forKey: .symbol) ?? Profile.defaultSymbol,
            pinnedApps: try container.decodeIfPresent([String].self, forKey: .pinnedApps) ?? [],
            widgets: widgetNames.compactMap(WidgetKind.init(rawValue:)),
            desktop: try container.decodeIfPresent(Int.self, forKey: .desktop)
        )
    }
}

extension Profile {
    public static let defaults: [Profile] = [
        Profile(
            name: "Work",
            symbol: "briefcase.fill",
            pinnedApps: [
                "com.apple.finder",
                "com.apple.Safari",
                "com.apple.mail",
                "com.apple.iCal",
                "com.apple.Notes",
                "com.apple.Terminal",
            ],
            widgets: [.clock, .date, .claude, .users],
            desktop: 1
        ),
        Profile(
            name: "Chill",
            symbol: "cup.and.saucer.fill",
            pinnedApps: [
                "com.apple.finder",
                "com.apple.Music",
                "com.apple.Photos",
                "com.apple.MobileSMS",
                "com.apple.TV",
            ],
            widgets: [.spotify, .clock, .users],
            desktop: 2
        ),
    ]
}
