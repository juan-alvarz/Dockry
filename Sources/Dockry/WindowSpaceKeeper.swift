import AppKit
import ApplicationServices
import Combine
import DockryCore

/// Keeps other apps' windows out of the dock's space, as the macOS Dock does while it isn't
/// hiding. Only the macOS Dock can change the area macOS gives windows (what zooming fills,
/// where new windows go), so instead this watches windows through Accessibility and moves
/// or shrinks any that end up behind the dock: a zoomed window is cut to the space above it,
/// a window dragged under it comes back out once the mouse button is up.
@MainActor
final class WindowSpaceKeeper: ObservableObject {
    static let shared = WindowSpaceKeeper()

    /// The dock's space on one screen, in AppKit coordinates.
    struct Reservation: Equatable {
        var position: DockPosition
        /// The strip the dock keeps for itself.
        var dock: CGRect
        /// What's left for windows.
        var allowed: CGRect
    }

    /// One per screen with a dock; empty while the dock hides automatically, which, as with
    /// the macOS Dock, keeps no space.
    var reservations: [Reservation] = [] {
        didSet {
            guard reservations != oldValue else { return }
            recentlyAdjusted = [:]
            fitAllWindows()
        }
    }

    var isEnabled = false {
        didSet { if isEnabled != oldValue { updateObservers() } }
    }

    /// Whether Dockry has Accessibility access, which watching and moving windows needs.
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var observers: [pid_t: AXObserver] = [:]
    private var subscription: AnyCancellable?
    private var trustTimer: Timer?
    /// Windows that changed while the mouse button was down: the user may still be dragging
    /// them, so they're fitted once it's up.
    private var waitingForMouseUp: [AXUIElement] = []
    private var mouseUpTimer: Timer?
    /// When Dockry last moved each window. Its own change comes back as a notification, and
    /// an app that refuses a size (a minimum height, say) shouldn't be fought over.
    private var recentlyAdjusted: [CFHashCode: Date] = [:]

    private init() {
        subscription = NSWorkspace.shared.publisher(for: \.runningApplications)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateObservers() }
    }

    func requestAccess() {
        DesktopSwitcher.requestAccessibility()
    }

    /// Watches every regular app's windows while enabled and trusted.
    private func updateObservers() {
        isTrusted = AXIsProcessTrusted()
        guard isEnabled, isTrusted else {
            for pid in Array(observers.keys) {
                stopObserving(pid)
            }
            // Access is granted in System Settings, which tells Dockry nothing; check now and then.
            if isEnabled && trustTimer == nil {
                trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, AXIsProcessTrusted() else { return }
                        self.trustTimer?.invalidate()
                        self.trustTimer = nil
                        self.updateObservers()
                    }
                }
            }
            return
        }
        trustTimer?.invalidate()
        trustTimer = nil

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let pids = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .map(\.processIdentifier))
        for pid in observers.keys where !pids.contains(pid) {
            stopObserving(pid)
        }
        for pid in pids where observers[pid] == nil {
            startObserving(pid)
            fitWindows(of: pid)
        }
    }

    private func startObserving(_ pid: pid_t) {
        var created: AXObserver?
        guard AXObserverCreate(pid, windowChangedCallback, &created) == .success, let observer = created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXWindowCreatedNotification, kAXWindowMovedNotification, kAXWindowResizedNotification] {
            AXObserverAddNotification(observer, app, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func stopObserving(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func fitAllWindows() {
        for pid in observers.keys {
            fitWindows(of: pid)
        }
    }

    private func fitWindows(of pid: pid_t) {
        guard !reservations.isEmpty else { return }
        let app = AXUIElementCreateApplication(pid)
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success,
              let windows = windows as? [AXUIElement]
        else { return }
        windows.forEach(windowChanged)
    }

    fileprivate func windowChanged(_ window: AXUIElement) {
        guard isEnabled, !reservations.isEmpty else { return }
        if NSEvent.pressedMouseButtons & 1 != 0 {
            if !waitingForMouseUp.contains(where: { CFEqual($0, window) }) {
                waitingForMouseUp.append(window)
            }
            if mouseUpTimer == nil {
                mouseUpTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.fitWaitingWindows() }
                }
            }
            return
        }
        fit(window)
    }

    private func fitWaitingWindows() {
        guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
        mouseUpTimer?.invalidate()
        mouseUpTimer = nil
        let windows = waitingForMouseUp
        waitingForMouseUp = []
        windows.forEach(fit)
    }

    private func fit(_ window: AXUIElement) {
        guard Self.isOrdinaryWindow(window), let frame = Self.frame(of: window),
              let reservation = reservations.first(where: { $0.dock.intersects(frame) })
        else { return }
        let id = CFHash(window)
        if let last = recentlyAdjusted[id], Date().timeIntervalSince(last) < 1 { return }
        let fitted = WindowFit.frame(frame, avoiding: reservation.position, allowed: reservation.allowed).integral
        guard fitted != frame.integral else { return }
        recentlyAdjusted[id] = Date()
        Self.setFrame(fitted, of: window)
    }

    // MARK: Accessibility

    /// A normal window: not a panel, sheet or full-screen or minimized window.
    private static func isOrdinaryWindow(_ window: AXUIElement) -> Bool {
        guard attribute(kAXSubroleAttribute, of: window) as? String == kAXStandardWindowSubrole else { return false }
        if attribute(kAXMinimizedAttribute, of: window) as? Bool == true { return false }
        if attribute("AXFullScreen", of: window) as? Bool == true { return false }
        return true
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    /// Accessibility puts the origin at the top left of the main screen, AppKit at the
    /// bottom left; this is the height to flip by.
    private static var mainScreenTop: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    /// The window's frame in AppKit coordinates.
    private static func frame(of window: AXUIElement) -> CGRect? {
        guard let positionValue = attribute(kAXPositionAttribute, of: window),
              let sizeValue = attribute(kAXSizeAttribute, of: window),
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(x: position.x, y: mainScreenTop - position.y - size.height, width: size.width, height: size.height)
    }

    private static func setFrame(_ frame: CGRect, of window: AXUIElement) {
        var position = CGPoint(x: frame.minX, y: mainScreenTop - frame.maxY)
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position), let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        // Size, then position, then size again: an app may refuse a size that doesn't fit
        // where the window is until it has moved.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }
}

private func windowChangedCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let keeper = Unmanaged<WindowSpaceKeeper>.fromOpaque(refcon).takeUnretainedValue()
    // Observers' run loop sources are on the main run loop.
    MainActor.assumeIsolated { keeper.windowChanged(element) }
}
