import Foundation

/// What a widget is, for Settings and the profile editor: everything about it except how it
/// draws. Every widget, built in or (later) from a plugin, describes itself with one of these.
public struct WidgetInfo: Equatable {
    /// Something a widget needs from the Mac or from the user to work.
    public struct Requirement: Equatable {
        public var text: String
        /// Optional requirements only unlock extras; the widget works without them.
        public var isOptional: Bool

        public init(_ text: String, isOptional: Bool = false) {
            self.text = text
            self.isOptional = isOptional
        }
    }

    public enum Category: String, CaseIterable {
        case time = "Time"
        case media = "Media"
        case system = "System"
        case productivity = "Productivity"
    }

    public var kind: WidgetKind
    public var name: String
    /// One line: what it shows.
    public var summary: String
    /// What clicking it does, and how it looks in a dock on the side of the screen.
    public var details: String
    /// SF Symbol for its icon.
    public var symbol: String
    /// Its icon's color, as "#RRGGBB".
    public var tint: String
    public var category: Category
    public var requirements: [Requirement]
    /// Who made it; "Dockry" for the built-in ones.
    public var author: String

    public init(
        kind: WidgetKind, name: String, summary: String, details: String, symbol: String,
        tint: String, category: Category, requirements: [Requirement] = [], author: String = "Dockry"
    ) {
        self.kind = kind
        self.name = name
        self.summary = summary
        self.details = details
        self.symbol = symbol
        self.tint = tint
        self.category = category
        self.requirements = requirements
        self.author = author
    }
}

extension WidgetKind {
    public var info: WidgetInfo {
        switch self {
        case .clock:
            WidgetInfo(
                kind: self, name: "Clock",
                summary: "The time, in your Mac’s 12- or 24-hour format.",
                details: "Click it to open the Clock app. On a side dock the time sits above the AM/PM, so it fits a narrow tile.",
                symbol: "clock.fill", tint: "#636366", category: .time)
        case .date:
            WidgetInfo(
                kind: self, name: "Calendar",
                summary: "Today’s date, like a page of a desk calendar.",
                details: "Click it for the whole month. Use the arrows to look at other months, and Today to come back.",
                symbol: "calendar", tint: "#FF3B30", category: .time)
        case .spotify:
            WidgetInfo(
                kind: self, name: "Spotify",
                summary: "What’s playing in Spotify, with play/pause, previous and next.",
                details: "Click the song for the player: progress you can drag, volume, shuffle, repeat and search that plays songs without bringing Spotify to the front. On a side dock it’s the album art above the controls.",
                symbol: "music.note", tint: "#1DB954", category: .media,
                requirements: [
                    WidgetInfo.Requirement("The Spotify app"),
                    WidgetInfo.Requirement("Permission to control Spotify; macOS asks the first time"),
                    WidgetInfo.Requirement("A Spotify account connected below, to search", isOptional: true),
                ])
        case .users:
            WidgetInfo(
                kind: self, name: "Switch User",
                summary: "The Mac’s other accounts, for Fast User Switching.",
                details: "Click someone to switch to their account, as from the user menu in Control Center. With no other accounts, it opens the login window.",
                symbol: "person.2.fill", tint: "#0A84FF", category: .system,
                requirements: [WidgetInfo.Requirement("Fast User Switching, which macOS has on by default")])
        case .claude:
            WidgetInfo(
                kind: self, name: "Claude Usage",
                summary: "How much of your Claude plan’s 5-hour and weekly limits you’ve used.",
                details: "The same numbers as /usage in Claude Code, checked every few minutes. Click it for the usage page on claude.ai. On a side dock it’s a ring for the 5-hour limit.",
                symbol: "sparkle", tint: "#D97757", category: .productivity,
                requirements: [
                    WidgetInfo.Requirement("Claude Code, signed in with a Claude plan"),
                    WidgetInfo.Requirement("Permission to read Claude Code’s sign-in; macOS asks the first time"),
                ])
        }
    }
}

public enum WidgetCatalog {
    /// Every widget, in the order Settings lists them.
    public static let all: [WidgetInfo] = [WidgetKind.clock, .date, .spotify, .claude, .users].map(\.info)
}
