import AppKit
import DockryCore

/// Keeps a history of copied text, in memory only. macOS has no notification for clipboard
/// changes, so this checks the pasteboard's change counter twice a second, which is cheap.
/// It starts the first time something uses `shared`, i.e. when a profile shows the
/// clipboard widget.
@MainActor
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published private(set) var history = ClipboardHistory()
    @Published var isShowingHistory = false

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    /// Markers password managers and similar apps put on what they copy, so clipboard tools
    /// leave it alone (see nspasteboard.org).
    private static let privateTypes: Set<NSPasteboard.PasteboardType> = [
        .init("org.nspasteboard.ConcealedType"),
        .init("org.nspasteboard.TransientType"),
    ]

    private init() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop.
            MainActor.assumeIsolated { self?.checkForNewCopy() }
        }
    }

    /// Puts `text` back on the clipboard, ready to paste.
    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        history.add(text)
        isShowingHistory = false
    }

    func clear() {
        history.removeAll()
    }

    private func checkForNewCopy() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        let types = Set(pasteboard.types ?? [])
        guard types.isDisjoint(with: Self.privateTypes), let text = pasteboard.string(forType: .string) else { return }
        history.add(text)
    }
}
