import AppKit
import ApplicationServices
import DockryCore

/// Moves windows for ProfileWindowRecords, which decides: each window is in one profile, so
/// one app (Zen, say) can have windows in several. macOS can't hide one window of an app, so,
/// as AeroSpace does, the other profiles' windows are parked just past the bottom right
/// corner of all the screens together, and put back where they were when their profile is
/// active again. Every window stays on the macOS desktop it's on.
@MainActor
final class ProfileWindows {
    private var state: ProfileWindowRecords {
        didSet { if state != oldValue { save() } }
    }
    /// Accessibility's handle for each window seen, to move it.
    private var elements: [CGWindowID: AXUIElement] = [:]
    private static let savedKey = "profileWindows"

    init() {
        state = UserDefaults.standard.data(forKey: Self.savedKey)
            .flatMap { try? JSONDecoder().decode(ProfileWindowRecords.self, from: $0) } ?? ProfileWindowRecords()
    }

    /// A window almost entirely off every screen.
    static func isParked(_ frame: CGRect) -> Bool {
        let visible = NSScreen.screens.reduce(0) { total, screen in
            let part = screen.frame.intersection(frame)
            return total + (part.isNull ? 0 : part.width * part.height)
        }
        return visible < frame.width * frame.height * 0.05
    }

    /// The profiles the app has windows in.
    func profiles(of pid: pid_t) -> Set<String> {
        state.profiles(ofPID: pid)
    }

    /// The profile of the app's window in front, if Dockry knows it.
    func focusedProfile(of pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        guard let focused = AppWindows.attribute(kAXFocusedWindowAttribute, of: app), CFGetTypeID(focused) == AXUIElementGetTypeID(),
              let number = Self.number(of: focused as! AXUIElement)
        else { return nil }
        return state.profile(ofWindow: number)
    }

    /// Looks over the apps' windows: ones not seen before go to `profile(app)`, and ones the
    /// window server no longer has are forgotten.
    func scan(_ apps: [NSRunningApplication], profile: (NSRunningApplication) -> String?) {
        for app in apps {
            guard let newProfile = profile(app) else { continue }
            for element in AppWindows.shared.windows(of: app.processIdentifier).map(\.element) {
                guard let number = Self.number(of: element) else { continue }
                elements[number] = element
                state.see(number, pid: app.processIdentifier, newProfile: newProfile)
            }
        }
        let existing = Self.existingWindows()
        state.keep(only: existing)
        elements = elements.filter { existing.contains($0.key) }
    }

    /// A window that just opened goes to `profile`.
    func adopt(_ window: AXUIElement, pid: pid_t, into profile: String) {
        guard let number = Self.number(of: window) else { return }
        elements[number] = window
        state.see(number, pid: pid, newProfile: profile)
    }

    func rename(_ profile: String, to newName: String) {
        state.rename(profile, to: newName)
    }

    func moveWindows(notIn profiles: Set<String>, to profile: String) {
        state.moveWindows(notIn: profiles, to: profile)
    }

    /// Shows the profile's windows and parks the others', among the windows of `apps`.
    func show(_ profile: String, apps: [NSRunningApplication], separatesAll: Bool, freshProfiles: Set<String>) {
        let plan = state.switchPlan(
            to: profile, pids: Set(apps.map(\.processIdentifier)), separatesAll: separatesAll, freshProfiles: freshProfiles)
        plan.unpark.forEach(unpark)
        plan.park.forEach(park)
    }

    /// The app of the front window in `profile`, for the keyboard to go to after a switch.
    func frontApp(in profile: String) -> NSRunningApplication? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windows where window[kCGWindowLayer as String] as? Int == 0 {
            guard let number = window[kCGWindowNumber as String] as? CGWindowID, state.profile(ofWindow: number) == profile,
                  state.records[number]?.home == nil, let pid = window[kCGWindowOwnerPID as String] as? pid_t
            else { continue }
            return NSRunningApplication(processIdentifier: pid)
        }
        return nil
    }

    /// Brings forward one of the app's windows in `profile`: macOS brings forward the app's
    /// last window, which may be another profile's, parked.
    func raise(_ pid: pid_t, in profile: String) {
        guard let own = state.records.first(where: { $0.value.pid == pid && $0.value.profile == profile && $0.value.home == nil }),
              let element = elements[own.key]
        else { return }
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    /// Puts every parked window back, for when Dockry quits or stops keeping windows apart.
    /// Which profile each is in is kept.
    func unparkAll() {
        state.parkedWindows.forEach(unpark)
    }

    private func park(_ number: CGWindowID) {
        guard let element = elements[number], let frame = AppWindows.frame(of: element), !Self.isParked(frame),
              AppWindows.attribute(kAXMinimizedAttribute, of: element) as? Bool != true
        else { return }
        let screens = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        // One point of it stays on screen; macOS won't move a window wholly off.
        AppWindows.move(element, to: CGRect(
            x: screens.maxX - 1, y: screens.minY - frame.height + 1, width: frame.width, height: frame.height))
        // Only parked if it moved: some windows refuse.
        if let moved = AppWindows.frame(of: element), Self.isParked(moved) {
            state.parked(number, home: frame)
        } else {
            NSLog("Dockry windows: window \(number) didn't move off screen")
        }
    }

    private func unpark(_ number: CGWindowID) {
        guard let home = state.records[number]?.home else { return }
        if let element = elements[number] ?? element(of: number) {
            AppWindows.move(element, to: home)
        }
        state.unparked(number)
    }

    /// A window not seen since Dockry started (parked before a restart), found among its
    /// app's windows.
    private func element(of number: CGWindowID) -> AXUIElement? {
        guard let pid = state.records[number]?.pid else { return nil }
        let element = AppWindows.windowElements(of: pid).first { Self.number(of: $0) == number }
        elements[number] = element
        return element
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(state), forKey: Self.savedKey)
    }

    /// Every window the window server has, on any desktop.
    private static func existingWindows() -> Set<CGWindowID> {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
    }

    /// The window server's number for the window. The function is private to macOS but
    /// long-standing, and what window managers use.
    static func number(of window: AXUIElement) -> CGWindowID? {
        typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        var number: CGWindowID = 0
        return unsafeBitCast(symbol, to: GetWindow.self)(window, &number) == .success ? number : nil
    }
}
