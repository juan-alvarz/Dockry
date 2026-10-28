import AppKit
import Combine
import DockryCore
import SwiftUI

/// The borderless window that holds one dock: a transparent strip along one edge of a
/// screen, at the Dock's window level on every desktop. It never takes keyboard focus from
/// the app you're using. Spanning the whole edge lets SwiftUI size and center the dock
/// itself; clicks on the strip's transparent parts go through to the windows below.
final class DockPanel: NSPanel {
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
        hostingView.sizingOptions = []  // the panel has a fixed size; see place(on:)
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// - Parameter coversSystemDock: Whether the panel may use the system Dock's space (while
    ///   Dockry hides that Dock).
    func place(on screen: NSScreen, position: DockPosition, thickness: CGFloat, coversSystemDock: Bool) {
        // visibleFrame leaves out the menu bar and, while it's showing, the system Dock, so
        // the two docks never overlap.
        let visible = screen.visibleFrame
        let area = coversSystemDock
            ? NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: visible.maxY - screen.frame.minY)
            : visible
        let frame = switch position {
        case .bottom: NSRect(x: area.minX, y: area.minY, width: area.width, height: thickness)
        case .left: NSRect(x: area.minX, y: area.minY, width: thickness, height: area.height)
        case .right: NSRect(x: area.maxX - thickness, y: area.minY, width: thickness, height: area.height)
        }
        if frame != self.frame {
            setFrame(frame, display: true)
        }
    }
}

private final class DockHostingView<Content: View>: NSHostingView<Content> {
    /// Dockry is never the active app, so without this the first click on an icon would only
    /// focus the panel instead of opening the app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// One dock per screen that should have one (see DockPlacement), kept up to date as screens
/// come and go and as the settings change.
@MainActor
final class DockController {
    private let makeDock: (DockPointer) -> DockView
    private let settings: SettingsStore
    private var docks: [CGDirectDisplayID: (panel: DockPanel, pointer: DockPointer)] = [:]
    private var subscriptions: Set<AnyCancellable> = []

    /// Whether the docks may use the system Dock's space (while Dockry hides that Dock).
    var coversSystemDock = false {
        didSet {
            layOut()
            // The Dock relaunches when its settings change, and macOS updates visibleFrame
            // only once it's back, without telling us. Keep checking while it restarts.
            Task { [weak self] in
                for _ in 0..<10 {
                    try? await Task.sleep(for: .milliseconds(500))
                    self?.layOut()
                }
            }
        }
    }

    init(settings: SettingsStore, makeDock: @escaping (DockPointer) -> DockView) {
        self.settings = settings
        self.makeDock = makeDock
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layOut() }
            .store(in: &subscriptions)
        // Published values arrive before they're stored; lay out once they are.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.layOut() }
            .store(in: &subscriptions)
        layOut()
    }

    func layOut() {
        let dock = settings.dock
        let metrics = DockMetrics(dock)
        let screens = NSScreen.screens
        let chosen = DockPlacement.screens(screens.map(\.frame), position: dock.position).map { screens[$0] }

        let chosenIDs = Set(chosen.compactMap(\.displayID))
        for (id, removed) in docks where !chosenIDs.contains(id) {
            removed.panel.orderOut(nil)
            docks[id] = nil
        }
        for screen in chosen {
            guard let id = screen.displayID else { continue }
            let entry = docks[id] ?? makePanel()
            docks[id] = entry
            entry.panel.place(
                on: screen, position: dock.position, thickness: metrics.panelThickness,
                coversSystemDock: coversSystemDock)
            entry.pointer.metrics = metrics
            entry.pointer.autohides = dock.autohides
            entry.panel.orderFrontRegardless()
        }
    }

    private func makePanel() -> (panel: DockPanel, pointer: DockPointer) {
        let pointer = DockPointer()
        let panel = DockPanel(content: makeDock(pointer))
        pointer.window = panel
        return (panel, pointer)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
