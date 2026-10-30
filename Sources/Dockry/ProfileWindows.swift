import AppKit
import ApplicationServices

/// Windows per profile, like the workspaces of Linux desktops: each window belongs to one
/// profile, so one app (Zen, say) can have windows in several. macOS can't hide one window
/// of an app, so, as workspace tools do, the other profiles' windows are parked just past
/// the bottom right corner of all the screens together, and put back where they were when
/// their profile is active again. (macOS desktops can't do this: Dockry can't create them,
/// and with a desktop per screen, a profile would need one on each.)
///
/// Windows are known by the window server's number, which lasts as long as the window, so
/// what's saved survives Dockry restarting. A window is forgotten only once the window
/// server no longer has it.
@MainActor
final class ProfileWindows {
    private struct Record: Codable {
        var profile: String
        var pid: pid_t
        /// Where it was before it was parked; nil while it's on screen.
        var home: CGRect?
    }

    private var records: [CGWindowID: Record] {
        didSet { save() }
    }
    /// Accessibility's handle for each window seen, to move it.
    private var elements: [CGWindowID: AXUIElement] = [:]
    private static let savedKey = "profileWindows"

    init() {
        let data = UserDefaults.standard.data(forKey: Self.savedKey)
        let saved = data.flatMap { try? JSONDecoder().decode([String: Record].self, from: $0) } ?? [:]
        records = Dictionary(uniqueKeysWithValues: saved.compactMap { key, record in CGWindowID(key).map { ($0, record) } })
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
        Set(records.values.filter { $0.pid == pid }.map(\.profile))
    }

    /// Looks over the apps' windows: ones not seen before go to `profile(app)`, and ones the
    /// window server no longer has are forgotten.
    func scan(_ apps: [NSRunningApplication], profile: (NSRunningApplication) -> String?) {
        for app in apps {
            guard let newProfile = profile(app) else { continue }
            for element in AppWindows.shared.windows(of: app.processIdentifier).map(\.element) {
                guard let number = Self.number(of: element) else { continue }
                elements[number] = element
                // A saved number now used by another process's window is a new window.
                if records[number]?.pid != app.processIdentifier {
                    records[number] = Record(profile: newProfile, pid: app.processIdentifier)
                }
            }
        }
        let existing = Self.existingWindows()
        let gone = records.keys.filter { !existing.contains($0) }
        if !gone.isEmpty {
            gone.forEach { records[$0] = nil; elements[$0] = nil }
        }
    }

    /// A window that just opened goes to `profile`.
    func adopt(_ window: AXUIElement, pid: pid_t, into profile: String) {
        guard let number = Self.number(of: window) else { return }
        elements[number] = window
        if records[number]?.pid != pid {
            records[number] = Record(profile: profile, pid: pid)
        }
    }

    /// A renamed profile's windows stay its own.
    func rename(_ profile: String, to newName: String) {
        for (number, record) in records where record.profile == profile {
            records[number]?.profile = newName
        }
    }

    /// Moves all the app's windows to `profile`, back on screen.
    func move(_ pid: pid_t, to profile: String) {
        for (number, record) in records where record.pid == pid {
            unpark(number)
            records[number]?.profile = profile
        }
    }

    /// Shows the profile's windows and parks the others'. Only windows of `apps`.
    func show(_ profile: String, apps: [NSRunningApplication]) {
        let pids = Set(apps.map(\.processIdentifier))
        for (number, record) in records where pids.contains(record.pid) {
            if record.profile == profile { unpark(number) } else { park(number) }
        }
    }

    /// Brings forward one of the app's windows in `profile`, unless one already is: macOS
    /// brings forward the app's last window, which may be another profile's, parked.
    func raise(_ pid: pid_t, in profile: String) {
        let app = AXUIElementCreateApplication(pid)
        if let focused = AppWindows.attribute(kAXFocusedWindowAttribute, of: app), CFGetTypeID(focused) == AXUIElementGetTypeID(),
           let number = Self.number(of: focused as! AXUIElement), records[number]?.profile == profile {
            return
        }
        guard let own = records.first(where: { $0.value.pid == pid && $0.value.profile == profile && $0.value.home == nil }),
              let element = elements[own.key]
        else { return }
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    /// Puts every parked window back, for when Dockry quits or windows stop being per
    /// profile. Which profile each is in is kept.
    func unparkAll() {
        records.keys.forEach(unpark)
    }

    private func park(_ number: CGWindowID) {
        guard let record = records[number], record.home == nil, let element = elements[number],
              let frame = AppWindows.frame(of: element), !Self.isParked(frame),
              AppWindows.attribute(kAXMinimizedAttribute, of: element) as? Bool != true
        else { return }
        let screens = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        // One point of it stays on screen; macOS won't move a window wholly off.
        AppWindows.move(element, to: CGRect(
            x: screens.maxX - 1, y: screens.minY - frame.height + 1, width: frame.width, height: frame.height))
        // Only parked if it moved: some windows refuse.
        if let moved = AppWindows.frame(of: element), Self.isParked(moved) {
            records[number]?.home = frame
        } else {
            NSLog("Dockry: window \(number) didn't move off screen")
        }
    }

    private func unpark(_ number: CGWindowID) {
        guard let home = records[number]?.home else { return }
        if let element = elements[number] {
            AppWindows.move(element, to: home)
        }
        records[number]?.home = nil
    }

    private func save() {
        let saved = Dictionary(uniqueKeysWithValues: records.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: Self.savedKey)
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
