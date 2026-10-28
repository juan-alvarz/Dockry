import AppKit
import SwiftUI

/// The borderless window that holds the dock. It floats at the Dock's window level on every
/// desktop, never takes keyboard focus from the app you're using, and keeps itself centered
/// at the bottom of the main screen at the size of its content.
final class DockPanel: NSPanel {
    private let hostingView: NSView
    private let fit = FitScale()

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
        let fit = self.fit
        let hostingView = DockHostingView(rootView: ScaledToFit(fit: fit, content: content.fixedSize()))
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

        NotificationCenter.default.addObserver(
            self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        reposition()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Call when the dock's content may have changed size: apps launched or quit, or another
    /// profile. SwiftUI's own size callbacks (invalidateIntrinsicContentSize, preferences)
    /// turned out not to fire reliably in this panel.
    func contentDidChange() {
        // Measure once SwiftUI has applied the change.
        DispatchQueue.main.async { [weak self] in self?.reposition() }
    }

    @objc private func reposition() {
        // The first screen is the one with the menu bar.
        guard let screen = NSScreen.screens.first else { return }
        // visibleFrame excludes the system Dock while it's showing, so the two never overlap.
        let area = coversSystemDock ? screen.frame : screen.visibleFrame
        // Like the system Dock, shrink when there are too many apps to fit across the screen.
        // The intrinsic size is the unscaled one, since scaleEffect doesn't change layout.
        let fullSize = hostingView.intrinsicContentSize
        let scale = min(1, area.width / fullSize.width)
        if fit.scale != scale {
            fit.scale = scale
        }
        let size = CGSize(width: (fullSize.width * scale).rounded(.down), height: fullSize.height)
        let origin = CGPoint(x: (area.midX - size.width / 2).rounded(), y: area.minY)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

@MainActor
private final class FitScale: ObservableObject {
    @Published var scale: CGFloat = 1
}

/// Draws the dock at `fit.scale`, anchored to the bottom edge of the panel.
private struct ScaledToFit<Content: View>: View {
    @ObservedObject var fit: FitScale
    let content: Content

    var body: some View {
        content.scaleEffect(fit.scale, anchor: .bottom)
    }
}

private final class DockHostingView<Content: View>: NSHostingView<Content> {
    /// Dockry is never the active app, so without this the first click on an icon would only
    /// focus the panel instead of opening the app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
