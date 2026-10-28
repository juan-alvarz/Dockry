import Foundation

public enum WidgetKind: String, Codable, CaseIterable {
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
public struct Profile: Equatable {
    public static let defaultSymbol = "square.grid.2x2.fill"

    /// Profiles are identified by name, which keeps the JSON file easy to edit by hand.
    public var name: String
    /// SF Symbol shown for the profile in the dock and the menu bar.
    public var symbol: String
    /// The dock's contents after the profile button, in order: pinned apps, widgets, dividers
    /// and the place for open apps that aren't pinned. Each app and widget appears once, and
    /// the open apps' place always exists.
    public var items: [DockItem] {
        didSet { items = Self.normalized(items) }
    }
    /// Desktop number (1–9) to switch to on activation; nil stays on the current desktop.
    public var desktop: Int?
    /// The profile button's color, as "#RRGGBB"; nil for the plain gray button.
    public var color: String?
    /// A global keyboard shortcut that activates the profile; none unless the user sets one.
    public var shortcut: KeyShortcut?

    public init(
        name: String, symbol: String = Profile.defaultSymbol, items: [DockItem], desktop: Int? = nil,
        color: String? = nil, shortcut: KeyShortcut? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.items = Self.normalized(items)
        self.desktop = desktop
        self.color = color
        self.shortcut = shortcut
    }

    /// The pinned apps, then the open apps, then the widgets, with a divider between each.
    public init(
        name: String,
        symbol: String = Profile.defaultSymbol,
        pinnedApps: [String] = [],
        widgets: [WidgetKind] = [],
        desktop: Int? = nil,
        color: String? = nil
    ) {
        self.init(
            name: name, symbol: symbol,
            items: pinnedApps.map(DockItem.app) + [.divider, .runningApps, .divider] + widgets.map(DockItem.widget),
            desktop: desktop, color: color)
    }

    /// Bundle identifiers, in dock order. Setting it keeps the other items where they are:
    /// removed apps go, the rest take the places of the old ones, and new ones go after the last.
    public var pinnedApps: [String] {
        get { items.compactMap { if case .app(let bundleID) = $0 { bundleID } else { nil } } }
        set { replace({ if case .app = $0 { true } else { false } }, with: newValue.map(DockItem.app), orInsertAt: 0) }
    }

    /// The widgets, in dock order. Setting it works like `pinnedApps`; extra widgets go after
    /// the last widget, or at the end.
    public var widgets: [WidgetKind] {
        get { items.compactMap { if case .widget(let kind) = $0 { kind } else { nil } } }
        set { replace({ if case .widget = $0 { true } else { false } }, with: newValue.map(DockItem.widget), orInsertAt: items.count) }
    }

    /// Adds `item` at `index`, or moves it there if the dock already has it.
    public mutating func insert(_ item: DockItem, at index: Int) {
        var updated = items
        var index = index.clamped(to: 0...updated.count)
        if item != .divider, let existing = updated.firstIndex(of: item) {
            updated.remove(at: existing)
            if existing < index { index -= 1 }
        }
        updated.insert(item, at: index)
        items = updated
    }

    /// Removes the item at `index`, except the open apps' place.
    public mutating func removeItem(at index: Int) {
        guard items.indices.contains(index), items[index] != .runningApps else { return }
        items.remove(at: index)
    }

    private mutating func replace(_ matches: (DockItem) -> Bool, with new: [DockItem], orInsertAt fallback: Int) {
        // Removed ones go; the rest take the places left, in their new order.
        let kept = items.filter { !matches($0) || new.contains($0) }
        var remaining = new.filter { kept.contains($0) }.makeIterator()
        var updated: [DockItem] = []
        var lastSlot: Int?
        for item in kept {
            if matches(item), let next = remaining.next() {
                updated.append(next)
                lastSlot = updated.count
            } else {
                updated.append(item)
            }
        }
        let extra = new.filter { !kept.contains($0) }
        updated.insert(contentsOf: extra, at: min(lastSlot ?? fallback, updated.count))
        items = updated
    }

    /// Each app and widget once, and exactly one place for open apps (after the last pinned
    /// app if it's missing).
    private static func normalized(_ items: [DockItem]) -> [DockItem] {
        var seen = Set<DockItem>()
        var result = items.filter { $0 == .divider || seen.insert($0).inserted }
        if !seen.contains(.runningApps) {
            let afterApps = (result.lastIndex { if case .app = $0 { true } else { false } }).map { $0 + 1 } ?? 0
            result.insert(.runningApps, at: afterApps)
        }
        return result
    }
}

// Lenient decoding so a hand-written profile only needs a name, and a typo in a widget name
// drops that widget instead of making the whole file unreadable. Files from before `items`
// have `pinnedApps` and `widgets` instead.
extension Profile: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, symbol, items, pinnedApps, widgets, desktop, color, shortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? Profile.defaultSymbol
        let desktop = try container.decodeIfPresent(Int.self, forKey: .desktop)
        // Like a bad widget name, a bad color only drops the color.
        let color = (try? container.decodeIfPresent(String.self, forKey: .color)).flatMap { $0 }.flatMap(HexColor.normalized)
        if let items = try container.decodeIfPresent([String].self, forKey: .items) {
            self.init(name: name, symbol: symbol, items: items.compactMap(DockItem.init), desktop: desktop, color: color)
        } else {
            let widgetNames = try container.decodeIfPresent([String].self, forKey: .widgets) ?? []
            self.init(
                name: name, symbol: symbol,
                pinnedApps: try container.decodeIfPresent([String].self, forKey: .pinnedApps) ?? [],
                widgets: widgetNames.compactMap(WidgetKind.init(rawValue:)),
                desktop: desktop, color: color)
        }
        // Like a bad color, a bad shortcut only drops the shortcut.
        shortcut = (try? container.decodeIfPresent(KeyShortcut.self, forKey: .shortcut)).flatMap { $0 }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(desktop, forKey: .desktop)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
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
            desktop: 1,
            color: "#3563E9"
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
            desktop: 2,
            color: "#F08A4B"
        ),
    ]
}
