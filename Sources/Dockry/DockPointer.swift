import AppKit
import Combine
import DockryCore

/// Reports every pointer move, wherever it happens. Dockry is never the active app, so
/// SwiftUI's hover tracking can't be relied on in the dock. Mouse-moved events from a global
/// monitor need no permission but don't always arrive (not while another app tracks the
/// mouse, for one), so the location is also polled: a few times a second while the pointer
/// is elsewhere, every frame while it's over a dock.
@MainActor
final class PointerMonitor {
    static let shared = PointerMonitor()

    /// The pointer's location in screen coordinates (AppKit's: origin at the bottom left).
    let moves = PassthroughSubject<CGPoint, Never>()

    private var monitors: [Any] = []
    private var timer: Timer?
    private var lastLocation = CGPoint(x: -1, y: -1)
    private var fastRequests = 0

    private init() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }) {
            monitors.append(global)
        }
        // The global monitor misses events that go to Dockry's own windows.
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.check() }
            return event
        }) {
            monitors.append(local)
        }
        startTimer()
        BackgroundCursor.enable()
    }

    /// While someone needs smooth updates (the pointer is over a dock), poll every frame.
    func setFast(_ isFast: Bool) {
        let wasFast = fastRequests > 0
        fastRequests = max(fastRequests + (isFast ? 1 : -1), 0)
        if (fastRequests > 0) != wasFast {
            startTimer()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = fastRequests > 0 ? 1.0 / 60 : 0.12
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer?.tolerance = interval / 4
    }

    private func check() {
        let location = NSEvent.mouseLocation
        guard location != lastLocation else { return }
        lastLocation = location
        moves.send(location)
    }
}

/// Popovers and drags that keep an auto-hiding dock on screen while they're in use.
@MainActor
final class DockInteraction: ObservableObject {
    static let shared = DockInteraction()

    @Published private(set) var activeCount = 0

    var isBusy: Bool { activeCount > 0 }

    func begin() { activeCount += 1 }
    func end() { activeCount = max(activeCount - 1, 0) }
}

/// Where the pointer is relative to one dock window: what the magnification follows, which
/// icon shows its name, and whether an auto-hiding dock is showing.
@MainActor
final class DockPointer: ObservableObject {
    /// The pointer's location in the window's SwiftUI coordinates (origin at the top left),
    /// while it's over the dock.
    @Published private(set) var location: CGPoint?
    /// Where the pointer last was over the dock, kept after it leaves so magnification can
    /// shrink back from there.
    @Published private(set) var lastLocation: CGPoint?
    @Published private(set) var hoveredItem: String?
    @Published private(set) var isRevealed = true

    weak var window: NSWindow?
    var metrics = DockMetrics(DockSettings()) {
        didSet { if metrics != oldValue { update() } }
    }
    var autohides = false {
        didSet {
            guard autohides != oldValue else { return }
            isRevealed = !autohides
            update()
        }
    }
    /// The dock's frame at normal size, in the window's SwiftUI coordinates; set by DockView.
    var dockFrame: CGRect = .zero
    /// The app icons' frames in the window's SwiftUI coordinates, by bundle identifier.
    var itemFrames: [String: CGRect] = [:]
    /// The separators' frames, which show the resize cursor like the macOS Dock's divider.
    var separatorFrames: [String: CGRect] = [:]
    /// Widgets' frames, for the dock to know their lengths when one is dragged past them.
    var widgetFrames: [String: CGRect] = [:]
    /// False while the size follows the macOS Dock.
    var canResize = true
    /// While a separator is being dragged: where the drag started and the dock's size then.
    /// Kept here rather than in the separator, which can be rebuilt mid-drag.
    private var resizeStart: (mouse: CGPoint, size: Double)?
    /// While a separator is being dragged, the resize cursor stays wherever the pointer goes.
    var isResizing: Bool { resizeStart != nil }
    private var showsResizeCursor = false
    /// After the resize cursor goes, the arrow is set again for a moment, in case the one
    /// change was lost while the pointer crossed into another app's window.
    private var restoresArrowUntil = Date.distantPast

    private var subscriptions: Set<AnyCancellable> = []
    private var hideTask: Task<Void, Never>?

    init() {
        PointerMonitor.shared.moves
            .sink { [weak self] _ in self?.update() }
            .store(in: &subscriptions)
        DockInteraction.shared.$activeCount
            // After the change: the published value arrives before it's stored.
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &subscriptions)
    }

    /// Follows a separator being dragged: the dock grows as the pointer moves toward the
    /// middle of the screen. In screen coordinates, since the window itself resizes during
    /// the drag, which would throw off the gesture's own coordinates.
    func resize(_ settings: SettingsStore) {
        guard canResize else { return }
        let mouse = NSEvent.mouseLocation
        if resizeStart == nil {
            resizeStart = (mouse, settings.own.iconSize)
            DockInteraction.shared.begin()  // an auto-hiding dock stays up
            update()
        }
        guard let resizeStart else { return }
        let delta = switch metrics.position {
        case .bottom: mouse.y - resizeStart.mouse.y
        case .left: mouse.x - resizeStart.mouse.x
        case .right: resizeStart.mouse.x - mouse.x
        }
        settings.own.iconSize = (resizeStart.size + Double(delta)).rounded().clamped(to: DockSettings.sizeRange)
    }

    func endResize() {
        guard resizeStart != nil else { return }
        resizeStart = nil
        DockInteraction.shared.end()
        update()
    }

    func update() {
        guard let window else { return }
        // SwiftUI can drop the separator's drag without ending it when the dock's window
        // resizes or its row is rebuilt mid-drag. Without this the resize would never end,
        // and the resize cursor would follow the pointer everywhere for good.
        if isResizing && NSEvent.pressedMouseButtons & 1 == 0 {
            endResize()
            return
        }
        let screenPoint = NSEvent.mouseLocation
        let frame = window.frame
        let point = CGPoint(x: screenPoint.x - frame.minX, y: frame.maxY - screenPoint.y)

        let isOverDock = isRevealed && activeZone.contains(point)
        let newLocation = isOverDock ? point : nil
        if (newLocation == nil) != (location == nil) {
            PointerMonitor.shared.setFast(newLocation != nil)
            if ScreenshotHook.logsPointer {
                NSLog("Dockry pointer: \(isOverDock ? "over" : "left") the dock at \(point); dock frame \(dockFrame), \(itemFrames.count) icon frames")
            }
        }
        if newLocation != location {
            location = newLocation
            if let newLocation {
                lastLocation = newLocation
            }
        }
        let hovered = isOverDock ? itemFrames.first { $0.value.contains(point) }?.key : nil
        if hovered != hoveredItem {
            hoveredItem = hovered
        }
        if autohides {
            updateReveal(isOverDock: isOverDock, isAtEdge: isAtScreenEdge(point, in: frame.size))
        }
        let isOverSeparator = isOverDock && separatorFrames.values.contains {
            $0.insetBy(dx: metrics.axis == .horizontal ? -3 : 0, dy: metrics.axis == .vertical ? -3 : 0).contains(point)
        }
        updateCursor(resize: canResize && (isResizing || isOverSeparator))
    }

    private func updateCursor(resize: Bool) {
        if resize {
            // Set on every move: the app under the other windows may set its own cursor.
            (metrics.axis == .horizontal ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).set()
        } else if showsResizeCursor || Date() < restoresArrowUntil {
            if showsResizeCursor {
                restoresArrowUntil = Date().addingTimeInterval(0.3)
            }
            NSCursor.arrow.set()
        }
        showsResizeCursor = resize
    }

    /// Where the pointer counts as over the dock: the dock itself, plus the room magnified
    /// icons take up while magnifying.
    private var activeZone: CGRect {
        var zone = dockFrame.insetBy(dx: -1, dy: -1)
        guard location != nil, metrics.magnification > 1 else { return zone }
        let growth = metrics.iconSize * (metrics.magnification - 1)
        switch metrics.position {
        case .bottom: zone = CGRect(x: zone.minX, y: zone.minY - growth, width: zone.width, height: zone.height + growth)
        case .left: zone.size.width += growth
        case .right: zone = CGRect(x: zone.minX - growth, y: zone.minY, width: zone.width + growth, height: zone.height)
        }
        return zone
    }

    /// At the screen edge the dock is on, within the dock's span along it.
    private func isAtScreenEdge(_ point: CGPoint, in size: CGSize) -> Bool {
        let slack: CGFloat = 40
        switch metrics.position {
        case .bottom:
            return point.y >= size.height - 2 && point.x >= dockFrame.minX - slack && point.x <= dockFrame.maxX + slack
        case .left:
            return point.x <= 2 && point.y >= dockFrame.minY - slack && point.y <= dockFrame.maxY + slack
        case .right:
            return point.x >= size.width - 2 && point.y >= dockFrame.minY - slack && point.y <= dockFrame.maxY + slack
        }
    }

    private func updateReveal(isOverDock: Bool, isAtEdge: Bool) {
        if isAtEdge || isOverDock || DockInteraction.shared.isBusy {
            hideTask?.cancel()
            hideTask = nil
            if !isRevealed {
                isRevealed = true
            }
        } else if isRevealed && hideTask == nil {
            // Like the macOS Dock, linger a moment so a quick wobble doesn't hide it.
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, let self else { return }
                hideTask = nil
                isRevealed = false
                if location != nil {
                    location = nil
                    PointerMonitor.shared.setFast(false)
                }
                hoveredItem = nil
            }
        }
    }
}

/// Dockry is never the active app, and macOS ignores cursor changes from background apps,
/// so the separator's resize cursor wouldn't show. The window server has a per-connection
/// switch for this (private, used by other dock and window utilities); without it, the
/// cursor just stays an arrow.
enum BackgroundCursor {
    static func enable() {
        typealias DefaultConnection = @convention(c) () -> Int32
        typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let handle = dlopen(nil, RTLD_NOW),
              let defaultConnection = dlsym(handle, "_CGSDefaultConnection"),
              let setProperty = dlsym(handle, "CGSSetConnectionProperty")
        else { return }
        let connection = unsafeBitCast(defaultConnection, to: DefaultConnection.self)()
        _ = unsafeBitCast(setProperty, to: SetConnectionProperty.self)(
            connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }
}
