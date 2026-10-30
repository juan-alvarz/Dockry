import AppKit
import DockryCore
import SwiftUI

/// The Trash, like the macOS Dock's: empty or full, files dropped on it go to the Trash
/// (see DockPanel's DockHostingView), a click opens it, and its menu empties it.
struct TrashWidget: View {
    static let widget = DockWidget(
        info: WidgetKind.trash.info,
        makeView: { AnyView(TrashWidget()) },
        makeMenu: { AnyView(TrashMenu()) })

    @ObservedObject private var trash = TrashMonitor.shared
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        Button { trash.open() } label: {
            Image(nsImage: NSImage(named: trash.isFull ? NSImage.trashFullName : NSImage.trashEmptyName) ?? NSImage())
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .brightness(trash.isDropTarget ? -0.25 : 0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trash")
        .help("Trash")
        // Checked only while it's on screen.
        .onAppear { trash.widgetAppeared() }
        .onDisappear { trash.widgetDisappeared() }
    }
}

/// The Trash widget's own items in its right-click menu.
private struct TrashMenu: View {
    @ObservedObject private var trash = TrashMonitor.shared

    var body: some View {
        Button("Open") { trash.open() }
        Button("Empty Trash…") { trash.empty() }
            .disabled(!trash.isFull)
    }
}

/// Whether the Trash has anything in it, checked every couple of seconds while a Trash
/// widget is showing: the Trash can't be watched (or listed) without Full Disk Access, but
/// its number of entries can be read.
@MainActor
final class TrashMonitor: ObservableObject {
    static let shared = TrashMonitor()

    @Published private(set) var isFull = false
    /// Files are being dragged over a Trash widget.
    @Published var isDropTarget = false

    private static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
    private var visibleWidgets = 0
    private var timer: Timer?

    func widgetAppeared() {
        visibleWidgets += 1
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func widgetDisappeared() {
        visibleWidgets -= 1
        guard visibleWidgets == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func open() {
        NSWorkspace.shared.open(Self.url)
    }

    /// Files dropped on the Trash: moved there, so they can still be put back.
    func moveToTrash(_ urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                NSLog("Dockry: couldn't move \(url.path) to the Trash: \(error)")
            }
        }
        refresh()
    }

    /// Asks first, as Finder does, then has Finder empty the Trash.
    func empty() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to permanently erase the items in the Trash?"
        alert.informativeText = "You can’t undo this action."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        let emptyButton = alert.addButton(withTitle: "Empty Trash")
        emptyButton.hasDestructiveAction = true
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        Task {
            if await AppleScript.run(#"tell application id "com.apple.finder" to empty trash"#) == nil {
                Self.explainFinderAutomation()
            }
            refresh()
        }
    }

    private func refresh() {
        let count = (try? Self.url.resourceValues(forKeys: [.directoryEntryCountKey]))?.directoryEntryCount ?? 0
        let hasDSStore = FileManager.default.fileExists(atPath: Self.url.appendingPathComponent(".DS_Store").path)
        let full = TrashState.isFull(entryCount: count, hasDSStore: hasDSStore)
        if full != isFull {
            isFull = full
        }
    }

    private static func explainFinderAutomation() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Dockry couldn’t empty the Trash"
        alert.informativeText = "To empty the Trash from the dock, turn on Finder under Dockry in System Settings › Privacy & Security › Automation."
        alert.addButton(withTitle: "Open Automation Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
