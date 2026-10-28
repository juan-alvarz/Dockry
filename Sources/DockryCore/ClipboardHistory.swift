/// Recently copied text, newest first. Copying something that's already in the list moves
/// it back to the top instead of adding it twice.
public struct ClipboardHistory: Equatable {
    public static let defaultLimit = 20
    /// Bigger copies (a log file, a database dump) aren't kept: they'd hold a lot of memory
    /// for something nobody re-copies from a dock.
    public static let maxBytes = 100_000

    public private(set) var items: [String] = []
    public let limit: Int

    public init(limit: Int = ClipboardHistory.defaultLimit) {
        self.limit = limit
    }

    /// Ignores text that's only whitespace or bigger than `maxBytes`.
    public mutating func add(_ text: String) {
        guard text.utf8.count <= Self.maxBytes, text.contains(where: { !$0.isWhitespace }) else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        items = Array(items.prefix(limit))
    }

    public mutating func removeAll() {
        items.removeAll()
    }

    /// The start of the text on one line, for the list: runs of whitespace and line breaks
    /// become one space. Only the start is needed; the list shows a single line.
    public static func preview(of text: String) -> String {
        text.prefix(300).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
