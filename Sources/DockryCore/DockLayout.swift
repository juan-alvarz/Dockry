public struct DockEntry: Equatable, Identifiable {
    public let bundleID: String
    public let isPinned: Bool
    public let isRunning: Bool

    public var id: String { bundleID }
}

/// Something the dock shows after the profile button, made from one of the profile's items.
public struct DockElement: Equatable, Identifiable {
    public enum Content: Equatable {
        case app(DockEntry)
        case widget(WidgetKind)
        case divider
    }

    public let content: Content
    /// The profile item it comes from: for an open app that isn't pinned, the open apps' place.
    public let itemIndex: Int

    /// Apps by bundle identifier, as the dock tracks their frames.
    public var id: String {
        switch content {
        case .app(let entry): entry.bundleID
        case .widget(let kind): "widget:\(kind.rawValue)"
        case .divider: "divider:\(itemIndex)"
        }
    }

    public init(content: Content, itemIndex: Int) {
        self.content = content
        self.itemIndex = itemIndex
    }
}

public enum DockLayout {
    /// What the dock shows for `items`, in order. `running` is the open apps in launch order;
    /// those that aren't pinned go in the open apps' place, if `showsUnpinned`. Apps `isShown`
    /// rejects (not installed) are left out, and so are dividers with nothing to divide: at
    /// either end, or next to another divider.
    public static func elements(
        items: [DockItem], running: [String], showsUnpinned: Bool = true, isShown: (String) -> Bool = { _ in true }
    ) -> [DockElement] {
        let runningSet = Set(running)
        let pinned = Set(items.compactMap { if case .app(let bundleID) = $0 { bundleID } else { nil } })
        var result: [DockElement] = []
        for (index, item) in items.enumerated() {
            switch item {
            case .app(let bundleID) where isShown(bundleID):
                let entry = DockEntry(bundleID: bundleID, isPinned: true, isRunning: runningSet.contains(bundleID))
                result.append(DockElement(content: .app(entry), itemIndex: index))
            case .app:
                break
            case .widget(let kind):
                result.append(DockElement(content: .widget(kind), itemIndex: index))
            case .runningApps where showsUnpinned:
                var seen = pinned
                for bundleID in running where seen.insert(bundleID).inserted && isShown(bundleID) {
                    let entry = DockEntry(bundleID: bundleID, isPinned: false, isRunning: true)
                    result.append(DockElement(content: .app(entry), itemIndex: index))
                }
            case .runningApps:
                break
            case .divider:
                if let last = result.last, last.content != .divider {
                    result.append(DockElement(content: .divider, itemIndex: index))
                }
            }
        }
        if result.last?.content == .divider {
            result.removeLast()
        }
        return result
    }

    /// Where an element being dragged along the dock would land: its center has moved
    /// `distance` points from where it started, among elements `lengths` long with `spacing`
    /// between them.
    public static func dropIndex(from index: Int, distance: Double, lengths: [Double], spacing: Double) -> Int {
        let centers = Self.centers(lengths, spacing: spacing)
        let moved = centers[index] + distance
        // Reaching an element's center is enough to pass it.
        return centers.indices.filter { $0 != index && (centers[$0] < moved || (distance > 0 && centers[$0] == moved)) }.count
    }

    /// How far the element at `from` starts from where it did, once moved to `to`.
    public static func shift(from: Int, to: Int, lengths: [Double], spacing: Double) -> Double {
        if to > from {
            return lengths[(from + 1)...to].reduce(0) { $0 + $1 + spacing }
        } else {
            return -lengths[to..<from].reduce(0) { $0 + $1 + spacing }
        }
    }

    /// The profile's items after dragging the element at `from` to `to` among `elements`.
    /// Dragging an open app that isn't pinned pins it there, as in the macOS Dock.
    public static func items(
        _ items: [DockItem], afterMoving from: Int, to: Int, in elements: [DockElement]
    ) -> [DockItem] {
        guard from != to, elements.indices.contains(from), elements.indices.contains(to) else { return items }
        let element = elements[from]
        var others = elements
        others.remove(at: from)
        var result = items
        let moving: DockItem
        var removed: Int?
        switch element.content {
        case .app(let entry) where !entry.isPinned:
            moving = .app(entry.bundleID)
        default:
            moving = result.remove(at: element.itemIndex)
            removed = element.itemIndex
        }
        // Next to the element it now sits beside: before the one after it when it moved back,
        // after the one before it when it moved forward.
        var anchor = to < from ? others[to].itemIndex : others[to - 1].itemIndex
        if let removed, removed < anchor { anchor -= 1 }
        result.insert(moving, at: to < from ? anchor : anchor + 1)
        return result
    }

    private static func centers(_ lengths: [Double], spacing: Double) -> [Double] {
        var start = 0.0
        return lengths.map { length in
            defer { start += length + spacing }
            return start + length / 2
        }
    }
}
