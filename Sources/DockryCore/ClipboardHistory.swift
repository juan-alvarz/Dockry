/// Recently copied text, newest first. Copying something that's already in the list moves
/// it back to the top instead of adding it twice.
public struct ClipboardHistory: Equatable {
    public static let defaultLimit = 20

    public private(set) var items: [String] = []
    public let limit: Int

    public init(limit: Int = ClipboardHistory.defaultLimit) {
        self.limit = limit
    }

    /// Ignores text that's only whitespace.
    public mutating func add(_ text: String) {
        guard text.contains(where: { !$0.isWhitespace }) else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        items = Array(items.prefix(limit))
    }

    public mutating func removeAll() {
        items.removeAll()
    }

    /// The text on one line, for the list: runs of whitespace and line breaks become one space.
    public static func preview(of text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
