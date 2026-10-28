import AppKit
import SwiftUI

/// The borderless window that holds the dock. It floats at the Dock's window level on every
/// desktop, never takes keyboard focus from the app you're using, and keeps itself centered
/// at the bottom of the main screen at the size of its content.
final class DockPanel: NSPanel {
    private let hostingView: NSView

    /// Whether the panel may use the system Dock's space at the bottom of the screen (while
    /// Dockry hides that Dock).
    var coversSystemDock = false {
        didSet {
            reposition()
            // The Dock relaunches when its settings change, and macOS updates visibleFrame
            // only once it's back, without telling us. Look again after it has restarted.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.reposition() }
        }
    }

    init<Content: View>(content: Content) {
        let hostingView = DockHostingView(rootView: content.fixedSize())
        hostingView.sizingOptions = [.intrinsicContentSize]
        self.hostingView = hostingView
        super.init(
            contentRect: NSRect(origin: .zero, size: hostingView.intrinsicContentSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // the SwiftUI content draws its own
        hidesOnDeactivate = false
        contentView = hostingView

        hostingView.onSizeChange = { [weak self] in self?.reposition() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        reposition()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @objc private func reposition() {
        // The first screen is the one with the menu bar.
        guard let screen = NSScreen.screens.first else { return }
        let size = hostingView.intrinsicContentSize
        // visibleFrame excludes the system Dock while it's showing, so the two never overlap.
        let area = coversSystemDock ? screen.frame : screen.visibleFrame
        let origin = CGPoint(x: (area.midX - size.width / 2).rounded(), y: area.minY)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

private final class DockHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: (() -> Void)?

    /// Dockry is never the active app, so without this the first click on an icon would only
    /// focus the panel instead of opening the app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// SwiftUI calls this when the dock's ideal size changes, e.g. when an app launches.
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // Resizing the window in the middle of SwiftUI's layout pass doesn't stick; do it after.
        DispatchQueue.main.async { [weak self] in self?.onSizeChange?() }
    }
}
