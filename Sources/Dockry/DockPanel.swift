import AppKit
import SwiftUI

/// The borderless window that holds the dock: a transparent strip along the bottom of the
/// main screen, at the Dock's window level on every desktop. It never takes keyboard focus
/// from the app you're using. Spanning the full width lets SwiftUI size and center the dock
/// itself; clicks on the strip's transparent parts go through to the windows below.
final class DockPanel: NSPanel {
    /// Whether the panel may use the system Dock's space at the bottom of the screen (while
    /// Dockry hides that Dock).
    var coversSystemDock = false {
        didSet {
            reposition()
            // The Dock relaunches when its settings change, and macOS updates visibleFrame
            // only once it's back, without telling us. Keep checking while it restarts.
            for delay in stride(from: 0.5, through: 5, by: 0.5) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.reposition() }
            }
        }
    }

    init<Content: View>(content: Content) {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // the SwiftUI content draws its own
        hidesOnDeactivate = false
        let hostingView = DockHostingView(rootView: content)
        hostingView.sizingOptions = []  // the panel has a fixed size; see reposition()
        contentView = hostingView

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
        // visibleFrame excludes the system Dock while it's showing, so the two never overlap.
        let area = coversSystemDock ? screen.frame : screen.visibleFrame
        setFrame(NSRect(x: area.minX, y: area.minY, width: area.width, height: DockView.panelHeight), display: true)
    }
}

private final class DockHostingView<Content: View>: NSHostingView<Content> {
    /// Dockry is never the active app, so without this the first click on an icon would only
    /// focus the panel instead of opening the app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
