import AppKit
import SwiftUI

/// The borderless window that holds the dock. It floats at the Dock's window level on every
/// desktop, never takes keyboard focus from the app you're using, and keeps itself centered
/// at the bottom of the main screen at the size of its content.
final class DockPanel: NSPanel {
    private let sizing = PanelSizing()

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
        let sizing = self.sizing
        let hostingView = DockHostingView(rootView: MeasuredAndScaled(sizing: sizing, content: content.fixedSize()))
        hostingView.sizingOptions = []  // the panel sizes itself from what SwiftUI measures
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 100),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // the SwiftUI content draws its own
        hidesOnDeactivate = false
        contentView = hostingView

        sizing.onResize = { [weak self] in self?.reposition() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @objc private func reposition() {
        // The first screen is the one with the menu bar.
        guard let screen = NSScreen.screens.first, sizing.contentSize != .zero else { return }
        // visibleFrame excludes the system Dock while it's showing, so the two never overlap.
        let area = coversSystemDock ? screen.frame : screen.visibleFrame
        // Like the system Dock, shrink when there are too many apps to fit across the screen.
        let fullSize = sizing.contentSize
        let scale = min(1, area.width / fullSize.width)
        if sizing.scale != scale {
            sizing.scale = scale
        }
        let size = CGSize(width: (fullSize.width * scale).rounded(.down), height: fullSize.height)
        let origin = CGPoint(x: (area.midX - size.width / 2).rounded(), y: area.minY)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

/// Connects the SwiftUI content's measured size to the panel, and the panel's scale back.
@MainActor
private final class PanelSizing: ObservableObject {
    @Published var scale: CGFloat = 1
    /// The dock's full (unscaled) size, as SwiftUI laid it out.
    private(set) var contentSize = CGSize.zero
    var onResize: (() -> Void)?

    func contentDidResize(to size: CGSize) {
        contentSize = size
        // Resizing the window during SwiftUI's layout pass doesn't stick, so do it right after.
        DispatchQueue.main.async { [weak self] in self?.onResize?() }
    }
}

/// Reports the content's size and draws it at the panel's scale, anchored to the bottom edge.
private struct MeasuredAndScaled<Content: View>: View {
    @ObservedObject var sizing: PanelSizing
    let content: Content

    var body: some View {
        content
            // scaleEffect doesn't change layout, so this is always the unscaled size.
            .background(GeometryReader { Color.clear.preference(key: ContentSizeKey.self, value: $0.size) })
            .onPreferenceChange(ContentSizeKey.self) { size in
                // SwiftUI calls this on the main thread.
                MainActor.assumeIsolated { sizing.contentDidResize(to: size) }
            }
            .scaleEffect(sizing.scale, anchor: .bottom)
    }
}

private struct ContentSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private final class DockHostingView<Content: View>: NSHostingView<Content> {
    /// Dockry is never the active app, so without this the first click on an icon would only
    /// focus the panel instead of opening the app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
