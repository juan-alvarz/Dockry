import AppKit
import SwiftUI

/// The borderless window that holds the dock. It floats at the Dock's window level on every
/// desktop, never takes keyboard focus from the app you're using, and keeps itself centered
/// at the bottom of the main screen at the size of its content.
final class DockPanel: NSPanel {
    private var contentSize = CGSize.zero

    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 100), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // the SwiftUI content draws its own
        hidesOnDeactivate = false

        let sizedContent = content
            .fixedSize()
            .background(GeometryReader { Color.clear.preference(key: ContentSizeKey.self, value: $0.size) })
            .onPreferenceChange(ContentSizeKey.self) { [weak self] size in
                // SwiftUI calls this on the main thread.
                MainActor.assumeIsolated {
                    self?.contentSize = size
                    self?.reposition()
                }
            }
        let hostingView = FirstClickHostingView(rootView: sizedContent)
        hostingView.sizingOptions = []  // the panel sizes itself from the preference above
        contentView = hostingView

        NotificationCenter.default.addObserver(
            self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @objc private func reposition() {
        // The first screen is the one with the menu bar.
        guard let screen = NSScreen.screens.first, contentSize != .zero else { return }
        // visibleFrame excludes the system Dock while it's showing, so the two never overlap.
        let area = screen.visibleFrame
        let origin = CGPoint(x: (area.midX - contentSize.width / 2).rounded(), y: area.minY)
        setFrame(NSRect(origin: origin, size: contentSize), display: true)
    }
}

/// Dockry is never the active app, so without this the first click on an icon would only
/// focus the panel instead of opening the app.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct ContentSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
