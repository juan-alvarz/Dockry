import AppKit
import ApplicationServices
import Combine

/// Watches other apps' windows through Accessibility: which are minimized, for the dock's
/// dots and window lists, and when one moves or resizes, for WindowSpaceKeeper. One
/// Accessibility observer per app, whichever of those needs it.
@MainActor
final class AppWindows: ObservableObject {
    static let shared = AppWindows()

    struct Window {
        let element: AXUIElement
        let title: String
        let isMinimized: Bool
    }

    /// Whether Dockry has Accessibility access, which watching windows needs.
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    /// How many minimized windows each app has; apps with none are left out.
    @Published private(set) var minimizedCounts: [pid_t: Int] = [:]
    /// Called when a window opens, moves or resizes.
    var windowChanged: ((AXUIElement) -> Void)?

    private var observers: [pid_t: AXObserver] = [:]
    /// Apps that weren't ready to be watched yet, and how many more times to try.
    private var retries: [pid_t: Int] = [:]
    private var subscriptions: Set<AnyCancellable> = []
    private var trustTimer: Timer?

    private init() {
        // A hung app shouldn't hold up the dock for the default six seconds.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)
        NSLog("Dockry: Accessibility access \(isTrusted ? "granted" : "not granted yet")")
        // Launches and quits, and activations: some apps (Electron ones, those that start in
        // the menu bar) only become regular apps later, which posts nothing else.
        Publishers.Merge(
            NSWorkspace.shared.publisher(for: \.runningApplications).map { _ in () },
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification).map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.updateObservers() }
        .store(in: &subscriptions)
        updateObservers()
    }

    func requestAccess() {
        DesktopSwitcher.requestAccessibility()
    }

    /// The app's windows, in Accessibility's order (front to back), minimized ones included.
    /// A minimized window doesn't report itself as a standard window, so it counts as one.
    func windows(of pid: pid_t) -> [Window] {
        Self.windowElements(of: pid).compactMap { element in
            let isMinimized = Self.attribute(kAXMinimizedAttribute, of: element) as? Bool == true
            guard isMinimized || Self.isStandard(element) else { return nil }
            return Window(
                element: element, title: Self.attribute(kAXTitleAttribute, of: element) as? String ?? "",
                isMinimized: isMinimized)
        }
    }

    /// Brings a window forward, out of the Dock's minimized windows if it's there.
    func show(_ window: AXUIElement, of app: NSRunningApplication) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        app.activate()
    }

    private func updateObservers() {
        isTrusted = AXIsProcessTrusted()
        guard isTrusted else {
            observers.keys.forEach(stopObserving)
            minimizedCounts = [:]
            // Access is granted in System Settings, which tells Dockry nothing; check now and then.
            if trustTimer == nil {
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
        }
    }

    private func startObserving(_ pid: pid_t) {
        var created: AXObserver?
        guard AXObserverCreate(pid, windowCallback, &created) == .success, let observer = created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications = [
            kAXWindowCreatedNotification, kAXWindowMovedNotification, kAXWindowResizedNotification,
            kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        ]
        let added = notifications.filter { AXObserverAddNotification(observer, app, $0 as CFString, refcon) == .success }
        // An app that has just launched may not answer yet; try again shortly, a few times.
        guard !added.isEmpty else {
            let left = retries[pid, default: 5] - 1
            retries[pid] = left
            if left > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, observers[pid] == nil else { return }
                    startObserving(pid)
                }
            }
            return
        }
        retries[pid] = nil
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
        updateMinimized(pid)
        Self.windowElements(of: pid).forEach { windowChanged?($0) }
    }

    private func stopObserving(_ pid: pid_t) {
        retries[pid] = nil
        minimizedCounts[pid] = nil
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    /// Fits every watched window again, after the dock's space changed.
    func refitAll() {
        for pid in observers.keys {
            Self.windowElements(of: pid).forEach { windowChanged?($0) }
        }
    }

    fileprivate func handle(_ notification: String, window: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        switch notification {
        case kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification:
            updateMinimized(pid)
            // The notification can come before the window's state changes, while it animates.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.updateMinimized(pid) }
        case kAXWindowCreatedNotification:
            updateMinimized(pid)
            windowChanged?(window)
        default:
            windowChanged?(window)
        }
    }

    private func updateMinimized(_ pid: pid_t) {
        let count = windows(of: pid).filter(\.isMinimized).count
        let value = count > 0 ? count : nil
        if minimizedCounts[pid] != value {
            minimizedCounts[pid] = value
        }
    }

    // MARK: Accessibility

    static func windowElements(of pid: pid_t) -> [AXUIElement] {
        attribute(kAXWindowsAttribute, of: AXUIElementCreateApplication(pid)) as? [AXUIElement] ?? []
    }

    /// A normal window: not a panel or sheet.
    static func isStandard(_ window: AXUIElement) -> Bool {
        attribute(kAXSubroleAttribute, of: window) as? String == kAXStandardWindowSubrole
    }

    static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}

private func windowCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let windows = Unmanaged<AppWindows>.fromOpaque(refcon).takeUnretainedValue()
    // Observers' run loop sources are on the main run loop.
    MainActor.assumeIsolated { windows.handle(notification as String, window: element) }
}
