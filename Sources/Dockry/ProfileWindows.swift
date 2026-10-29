import AppKit
import ApplicationServices

/// Windows per profile, like macOS desktops but for Dockry's profiles: a window belongs to
/// the profile that was active when it opened, so one app (Zen, say) can have windows in
/// several profiles. macOS can't hide one window of an app, so, as workspace tools do, the
/// other profiles' windows are parked just past the screen's bottom right corner, and put
/// back where they were when their profile is active again.
@MainActor
final class ProfileWindows {
    private struct Tracked {
        let element: AXUIElement
        let number: CGWindowID?
        var profile: String
        /// Where it was before it was parked; nil while it's on screen.
        var home: CGRect?
    }

    private var tracked: [pid_t: [Tracked]] = [:] {
        didSet { save() }
    }
    /// Profiles by window number, saved so a restart of Dockry (an update, say) keeps them;
    /// only windows that still exist.
    private var saved: [String: String] = {
        let saved = UserDefaults.standard.dictionary(forKey: ProfileWindows.savedKey) as? [String: String] ?? [:]
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let existing = Set(windows.compactMap { ($0[kCGWindowNumber as String] as? Int).map(String.init) })
        return saved.filter { existing.contains($0.key) }
    }()
    private static let savedKey = "windowProfiles"

    /// A window almost entirely off every screen: parked here, or after Dockry quit without
    /// putting it back (a crash).
    static func isParked(_ frame: CGRect) -> Bool {
        let visible = NSScreen.screens.reduce(0) { total, screen in
            let part = screen.frame.intersection(frame)
            return total + (part.isNull ? 0 : part.width * part.height)
        }
        return visible < frame.width * frame.height * 0.05
    }

    /// The profiles the app has windows in, as last seen.
    func profiles(of app: NSRunningApplication) -> Set<String> {
        Set(tracked[app.processIdentifier, default: []].map(\.profile))
    }

    /// A new window belongs to the active profile.
    func adopt(_ window: AXUIElement, into profile: String) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        guard !tracked[pid, default: []].contains(where: { CFEqual($0.element, window) }) else { return }
        tracked[pid, default: []].append(Tracked(element: window, number: Self.number(of: window), profile: profile))
    }

    func forget(_ pid: pid_t) {
        tracked[pid] = nil
    }

    /// Shows the profile's windows and parks the others'. An app with no windows in the
    /// profile is hidden; one with no windows at all goes by `owner`, as without windows per
    /// profile.
    func show(_ profile: String, apps: [NSRunningApplication], owner: (NSRunningApplication) -> String?) {
        for app in apps {
            guard let appOwner = owner(app) else { continue }  // in every profile
            let windows = refresh(app, adoptingInto: appOwner)
            if windows.isEmpty {
                if appOwner == profile { app.unhide() } else if !app.isHidden { app.hide() }
                continue
            }
            guard windows.contains(where: { $0.profile == profile }) else {
                if !app.isHidden { app.hide() }
                continue
            }
            // Parked before the app shows again, so the others' windows never flash by.
            park(app, except: profile)
            for index in tracked[app.processIdentifier, default: []].indices {
                unpark(app.processIdentifier, index, ifIn: profile)
            }
            if app.isHidden { app.unhide() }
        }
    }

    /// Parks the app's windows that aren't in `profile`, for opening a window of its own there.
    func park(_ app: NSRunningApplication, except profile: String) {
        let pid = app.processIdentifier
        for index in tracked[pid, default: []].indices where tracked[pid]![index].profile != profile {
            let window = tracked[pid]![index]
            guard window.home == nil, let frame = AppWindows.frame(of: window.element), !Self.isParked(frame),
                  AppWindows.attribute(kAXMinimizedAttribute, of: window.element) as? Bool != true
            else { continue }
            tracked[pid]![index].home = frame
            let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) } ?? NSScreen.screens[0]
            // One point of it stays on screen; macOS won't move a window wholly off.
            AppWindows.move(window.element, to: CGRect(
                x: screen.frame.maxX - 1, y: screen.frame.minY - frame.height + 1, width: frame.width, height: frame.height))
        }
    }

    /// Moves all the app's windows to `profile`, back on screen.
    func move(_ app: NSRunningApplication, to profile: String) {
        let pid = app.processIdentifier
        for index in tracked[pid, default: []].indices {
            unpark(pid, index, ifIn: nil)
            tracked[pid]![index].profile = profile
        }
    }

    /// Brings forward one of the app's windows in `profile`, instead of another profile's
    /// parked one that macOS would have brought forward.
    func raise(_ app: NSRunningApplication, in profile: String) {
        let windows = tracked[app.processIdentifier, default: []]
        let focused = AppWindows.attribute(kAXFocusedWindowAttribute, of: AXUIElementCreateApplication(app.processIdentifier))
        if let focused, windows.contains(where: { CFEqual($0.element, focused) && $0.profile == profile }) { return }
        guard let own = windows.first(where: { $0.profile == profile }) else { return }
        AXUIElementPerformAction(own.element, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(own.element, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    /// Puts every parked window back, for when windows stop being per profile or Dockry quits.
    func unparkAll() {
        for (pid, windows) in tracked {
            for index in windows.indices {
                unpark(pid, index, ifIn: nil)
            }
        }
    }

    /// Windows left parked by a Dockry that didn't get to put them back come back on screen.
    static func rescueParkedWindows() {
        guard AXIsProcessTrusted(), let screen = NSScreen.screens.first else { return }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            for window in AppWindows.windowElements(of: app.processIdentifier) {
                guard AppWindows.isStandard(window), let frame = AppWindows.frame(of: window), isParked(frame) else { continue }
                let visible = screen.visibleFrame
                AppWindows.move(window, to: CGRect(
                    x: visible.minX + 40, y: visible.maxY - 40 - frame.height, width: frame.width, height: frame.height))
            }
        }
    }

    private func save() {
        for window in tracked.values.joined() {
            if let number = window.number {
                saved[String(number)] = window.profile
            }
        }
        UserDefaults.standard.set(saved, forKey: Self.savedKey)
    }

    /// The window server's number for the window, which lasts as long as the window. The
    /// function is private to macOS but long-standing, and what window managers use.
    private static func number(of window: AXUIElement) -> CGWindowID? {
        typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        var number: CGWindowID = 0
        return unsafeBitCast(symbol, to: GetWindow.self)(window, &number) == .success ? number : nil
    }

    private func unpark(_ pid: pid_t, _ index: Int, ifIn profile: String?) {
        guard let window = tracked[pid]?[index], let home = window.home,
              profile == nil || window.profile == profile
        else { return }
        AppWindows.move(window.element, to: home)
        tracked[pid]![index].home = nil
    }

    /// The app's windows now: closed ones are dropped, and ones not seen before (open before
    /// windows were per profile) go to `profile`.
    private func refresh(_ app: NSRunningApplication, adoptingInto profile: String) -> [Tracked] {
        let pid = app.processIdentifier
        let current = AppWindows.shared.windows(of: pid).map(\.element)
        var windows = tracked[pid, default: []].filter { window in current.contains { CFEqual($0, window.element) } }
        for element in current where !windows.contains(where: { CFEqual($0.element, element) }) {
            let number = Self.number(of: element)
            windows.append(Tracked(element: element, number: number, profile: number.flatMap { saved[String($0)] } ?? profile))
        }
        tracked[pid] = windows
        return windows
    }
}
