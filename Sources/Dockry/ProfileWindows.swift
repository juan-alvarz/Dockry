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
    /// Apps already logged as refusing Accessibility, so each is logged once.
    private var warnedUnlisted: Set<pid_t> = []
    private static let savedKey = "profileWindows"

    init() {
        state = UserDefaults.standard.data(forKey: Self.savedKey)
            .flatMap { try? JSONDecoder().decode(ProfileWindowRecords.self, from: $0) } ?? ProfileWindowRecords()
    }

    /// A window almost entirely off every screen.
    static func isParked(_ frame: CGRect) -> Bool {
        WindowParking.isParked(frame, screens: screens)
    }

    private static var screens: [CGRect] {
        NSScreen.screens.map(\.frame)
    }

    /// Whether the window is in `profile`, or in none Dockry knows.
    func isIn(_ profile: String, _ window: AXUIElement) -> Bool {
        Self.number(of: window).flatMap(state.profile(ofWindow:)).map { $0 == profile } ?? true
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
        let onScreen = Self.onScreenWindowOwners()
        for app in apps {
            guard let newProfile = profile(app) else { continue }
            let found = AppWindows.shared.windows(of: app.processIdentifier).map(\.element)
            // Such an app's windows can't be moved, so they show in every profile. Asked
            // once per app: an app that doesn't answer takes a second each time.
            if found.isEmpty && onScreen.contains(app.processIdentifier) && warnedUnlisted.insert(app.processIdentifier).inserted {
                var value: CFTypeRef?
                let error = AXUIElementCopyAttributeValue(
                    AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute as CFString, &value)
                if error != .success {
                    NSLog("Dockry windows: \(app.localizedName ?? "an app") has windows on screen that Accessibility doesn't list (error \(error.rawValue))")
                }
            }
            for element in found {
                guard let number = Self.number(of: element) else { continue }
                elements[number] = element
                state.see(number, pid: app.processIdentifier, newProfile: newProfile)
            }
        }
        forgetClosed()
    }

    /// Forgets the windows that closed, and says whether any had. Without this an app
    /// would be taken to still have a window in a profile where its last one is gone.
    @discardableResult
    func forgetClosed() -> Bool {
        let existing = Self.existingWindows()
        // No windows at all is the window server not answering, not every window closing.
        guard !existing.isEmpty else { return false }
        let before = state
        state.keep(only: existing)
        elements = elements.filter { existing.contains($0.key) }
        return state != before
    }

    /// A window that just opened goes to `profile`.
    func adopt(_ window: AXUIElement, pid: pid_t, into profile: String) {
        guard let number = Self.number(of: window) else { return }
        elements[number] = window
        state.see(number, pid: pid, newProfile: profile)
    }

    /// Brings the app's front window to `profile`, for an app that can't open one there.
    /// False if Dockry knows none of its windows.
    func bringFrontWindow(of pid: pid_t, to profile: String) -> Bool {
        // Accessibility's order is front to back.
        guard let number = AppWindows.windowElements(of: pid).lazy.compactMap(Self.number(of:)).first(where: { self.state.records[$0] != nil })
        else { return false }
        state.move(number, to: profile)
        unpark(number)
        return true
    }

    /// Moves a window that's off screen, without having been parked, to the middle of the
    /// main screen: some apps open a new window next to their last one, which may be parked.
    func bringOnScreen(_ window: AXUIElement) {
        guard let frame = AppWindows.frame(of: window), Self.isParked(frame) else { return }
        AppWindows.move(window, to: WindowParking.home(frame, screens: Self.screens))
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
        plan.parked.forEach(parkAgain)
        plan.shown.forEach(rescue)
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
        // Accessibility's order is front to back: the profile's window used last.
        guard let element = AppWindows.windowElements(of: pid).first(where: { window in
            Self.number(of: window).flatMap { self.state.records[$0] }.map { $0.profile == profile && $0.home == nil } == true
        }) else { return }
        bringOnScreen(element)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    /// Puts every parked window back, for when Dockry quits or stops keeping windows apart.
    /// Which profile each is in is kept.
    func unparkAll() {
        state.parkedWindows.forEach(unpark)
    }

    private func park(_ number: CGWindowID) {
        // A full-screen window is on a desktop of its own and can't be moved.
        guard let element = elements[number], let frame = AppWindows.frame(of: element), !Self.isParked(frame),
              AppWindows.attribute(kAXMinimizedAttribute, of: element) as? Bool != true,
              AppWindows.attribute("AXFullScreen", of: element) as? Bool != true,
              let spot = WindowParking.spot(for: frame.size, screens: Self.screens)
        else { return }
        AppWindows.move(element, to: spot)
        // Only parked if it moved: some windows refuse.
        if let moved = AppWindows.frame(of: element), Self.isParked(moved) {
            state.parked(number, home: frame)
        } else {
            NSLog("Dockry windows: window \(number) didn't move off screen")
        }
    }

    /// Its place is kept until it's back there: a window that can't be reached now (its app
    /// isn't answering, or it's on another desktop) is tried again on the next switch.
    private func unpark(_ number: CGWindowID) {
        guard let home = state.records[number]?.home else { return }
        guard let element = elements[number] ?? element(of: number) else {
            NSLog("Dockry windows: window \(number) can't be reached to bring it back")
            return
        }
        AppWindows.move(element, to: WindowParking.home(home, screens: Self.screens))
        if let moved = AppWindows.frame(of: element), !Self.isParked(moved) {
            state.unparked(number)
        } else {
            NSLog("Dockry windows: window \(number) didn't come back on screen")
        }
    }

    /// A parked window that's showing again: macOS moves windows back on screen when a
    /// screen is unplugged, and a screen plugged in may cover where they were parked.
    private func parkAgain(_ number: CGWindowID) {
        guard let element = elements[number], let frame = AppWindows.frame(of: element), !Self.isParked(frame),
              let spot = WindowParking.spot(for: frame.size, screens: Self.screens)
        else { return }
        NSLog("Dockry windows: window \(number) was back on screen; parking it again")
        AppWindows.move(element, to: spot)
    }

    /// A window of the profile showing that's off screen with no place saved: it opened
    /// there, or its place was lost. Only ordinary windows: apps keep helpers off screen.
    private func rescue(_ number: CGWindowID) {
        guard let element = elements[number], let frame = AppWindows.frame(of: element), Self.isParked(frame),
              AppWindows.isStandard(element), AppWindows.attribute(kAXMinimizedAttribute, of: element) as? Bool != true
        else { return }
        NSLog("Dockry windows: window \(number) was off screen with no place saved; bringing it back")
        AppWindows.move(element, to: WindowParking.home(frame, screens: Self.screens))
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

    /// The apps with an ordinary window on screen, by process.
    private static func onScreenWindowOwners() -> Set<pid_t> {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.filter { $0[kCGWindowLayer as String] as? Int == 0 }.compactMap { $0[kCGWindowOwnerPID as String] as? pid_t })
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
