import AppKit
import ApplicationServices
import DockryCore

/// Keeps other apps' windows out of the dock's space, as the macOS Dock does while it isn't
/// hiding. Only the macOS Dock can change the area macOS gives windows (what zooming fills,
/// where new windows go), so instead this follows windows through Accessibility (AppWindows)
/// and moves or shrinks any that end up behind the dock: a zoomed window is cut to the space
/// above it, a window dragged under it comes back out once the mouse button is up.
@MainActor
final class WindowSpaceKeeper {
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
            AppWindows.shared.refitAll()
        }
    }

    var isEnabled = false

    /// Windows that changed while the mouse button was down: the user may still be dragging
    /// them, so they're fitted once it's up.
    private var waitingForMouseUp: [AXUIElement] = []
    private var mouseUpTimer: Timer?
    /// When Dockry last moved each window. Its own change comes back as a notification, and
    /// an app that refuses a size (a minimum height, say) shouldn't be fought over.
    private var recentlyAdjusted: [CFHashCode: Date] = [:]

    private init() {
        AppWindows.shared.windowChanged = { [weak self] in self?.windowChanged($0) }
    }

    private func windowChanged(_ window: AXUIElement) {
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
        guard AppWindows.isStandard(window) else { return false }
        if AppWindows.attribute(kAXMinimizedAttribute, of: window) as? Bool == true { return false }
        if AppWindows.attribute("AXFullScreen", of: window) as? Bool == true { return false }
        return true
    }

    /// Accessibility puts the origin at the top left of the main screen, AppKit at the
    /// bottom left; this is the height to flip by.
    private static var mainScreenTop: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    /// The window's frame in AppKit coordinates.
    private static func frame(of window: AXUIElement) -> CGRect? {
        guard let positionValue = AppWindows.attribute(kAXPositionAttribute, of: window),
              let sizeValue = AppWindows.attribute(kAXSizeAttribute, of: window),
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
