import AppKit
import Combine
import CoreAudio
import DockryCore

/// Gives each profile its own windows, like the workspaces of AeroSpace or Linux desktops:
/// a window is in the profile that was active when it opened, and switching parks the other
/// profiles' windows just off screen (ProfileWindows). The rules (ProfileAppRules) and the
/// records (ProfileWindowRecords) are in DockryCore with tests; this gathers the facts and
/// applies the answers. Nothing is hidden: apps stay as they are, only windows move.
@MainActor
final class ProfileApps: ObservableObject {
    /// The profile each open app opened in, by process.
    @Published private(set) var owners: [pid_t: String] = [:]
    /// The open apps playing sound right now.
    @Published private(set) var playingPIDs: Set<pid_t> = []
    /// Bumped when windows change profile or open, for the dock to follow.
    @Published private(set) var windowChanges = 0
    /// How many minimized windows each app has in the active profile, for the dock's dot.
    @Published private(set) var minimizedCounts: [pid_t: Int] = [:]

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            if !isEnabled {
                windows.unparkAll()
            }
            show(store.active.name)
        }
    }

    /// Switches to a profile, as the user would.
    var switchToProfile: ((String) -> Void)?

    private let store: ProfileStore
    private let windows = ProfileWindows()
    /// Apps just asked for a window of their own, which come forward before it's there.
    private var openingWindow: [pid_t: Date] = [:]
    private var subscriptions: Set<AnyCancellable> = []
    private var audioTimer: Timer?
    private static let savedOwnersKey = "appOwners"
    private static let sharedApps: Set<String> = ["com.apple.finder"]

    init(store: ProfileStore) {
        self.store = store
        // Apps open before Dockry started go back where they were, by process.
        let saved = UserDefaults.standard.data(forKey: Self.savedOwnersKey)
            .flatMap { try? JSONDecoder().decode(AppOwnership.self, from: $0) } ?? AppOwnership()
        for app in NSWorkspace.shared.runningApplications {
            assign(app, to: saved.profile(forPID: app.processIdentifier, launchedAt: app.launchDate) ?? store.active.name)
        }

        let center = NSWorkspace.shared.notificationCenter
        func apps(_ name: Notification.Name) -> AnyPublisher<NSRunningApplication, Never> {
            center.publisher(for: name)
                .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
                .eraseToAnyPublisher()
        }
        apps(NSWorkspace.willLaunchApplicationNotification)
            .merge(with: apps(NSWorkspace.didLaunchApplicationNotification))
            .sink { [weak self] app in
                guard let self, owners[app.processIdentifier] == nil else { return }
                assign(app, to: store.active.name)
            }
            .store(in: &subscriptions)
        apps(NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] app in
                self?.owners[app.processIdentifier] = nil
                self?.save()
            }
            .store(in: &subscriptions)
        apps(NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] app in self?.activated(app) }
            .store(in: &subscriptions)
        AppWindows.shared.windowCreated = { [weak self] window in
            guard let self else { return }
            var pid: pid_t = 0
            AXUIElementGetPid(window, &pid)
            guard let app = NSRunningApplication(processIdentifier: pid), let owner = owner(of: app) else { return }
            windows.forgetClosed()
            let asked = openingWindow[pid].map { Date().timeIntervalSince($0) < 3 } ?? false
            let profile = rules.newWindowProfile(
                owner: owner, active: store.active.name, asked: asked,
                opensOffScreen: AppWindows.frame(of: window).map(ProfileWindows.isParked) ?? false,
                windowProfiles: windows.profiles(of: pid), focusedProfile: windows.focusedProfile(of: pid))
            windows.adopt(window, pid: pid, into: profile)
            if asked {
                windows.bringOnScreen(window)
            }
            windowChanges += 1
        }
        // Published values arrive before they're stored; count once they are.
        AppWindows.shared.$minimizedCounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMinimized() }
            .store(in: &subscriptions)
        // A renamed profile keeps its apps and windows, under the new name. This arrives
        // before the sink below, which would otherwise take them for a removed profile's.
        store.renamed
            .sink { [weak self] from, to in
                guard let self else { return }
                for (pid, owner) in owners where owner == from {
                    owners[pid] = to
                }
                save()
                windows.rename(from, to: to)
            }
            .store(in: &subscriptions)
        // A removed profile's apps and windows go to the active profile.
        store.$library
            .receive(on: RunLoop.main)
            .sink { [weak self] library in
                guard let self else { return }
                let names = Set(library.profiles.map(\.name))
                for (pid, owner) in owners where !names.contains(owner) {
                    owners[pid] = library.activeProfileName
                }
                windows.moveWindows(notIn: names, to: library.activeProfileName)
            }
            .store(in: &subscriptions)
        // Core Audio has no notification for this that covers every process; checking is cheap.
        audioTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                let playing = AudioOutput.appPIDs()
                if playing != self?.playingPIDs {
                    self?.playingPIDs = playing
                }
            }
        }
    }

    /// The rules as the settings and profiles are now.
    var rules: ProfileAppRules {
        ProfileAppRules(isEnabled: isEnabled, freshProfiles: Set(store.library.profiles.filter(\.freshApps).map(\.name)))
    }

    /// Whether the dock shows the app in the active profile.
    func isShown(_ app: NSRunningApplication) -> Bool {
        rules.isShown(owner: owner(of: app), windowProfiles: windows.profiles(of: app.processIdentifier), active: store.active.name)
    }

    /// Whether the app is a fresh profile's own copy.
    func isFreshCopy(_ app: NSRunningApplication) -> Bool {
        owner(of: app).map(rules.isFresh) == true
    }

    /// The profiles with an app playing sound.
    var playingProfiles: Set<String> {
        let rules = rules
        return playingPIDs.reduce(into: []) { profiles, pid in
            guard let app = NSRunningApplication(processIdentifier: pid) else { return }
            profiles.formUnion(rules.profiles(owner: owner(of: app), windowProfiles: windows.profiles(of: pid)))
        }
    }

    /// The profile an app belongs to; nil for apps in every profile.
    func owner(of app: NSRunningApplication) -> String? {
        app.bundleIdentifier.map(Self.sharedApps.contains) == true ? nil : owners[app.processIdentifier]
    }

    /// Shows the profile's windows and parks the others', after switching to it, then gives
    /// the keyboard to the profile's front window (or Finder), so it doesn't stay with a
    /// window that just went off screen. Without `movingFocus` it only looks again, for
    /// when the windows to look at changed (another macOS desktop, other screens).
    func show(_ profile: String, movingFocus: Bool = true) {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != .current }
        let shared = apps.filter { owner(of: $0) != nil }
        windows.scan(shared) { [self] in owner(of: $0) }
        windows.show(profile, apps: shared, separatesAll: isEnabled, freshProfiles: rules.freshProfiles)
        windowChanges += 1
        updateMinimized()
        guard movingFocus, let front = NSWorkspace.shared.frontmostApplication, front != .current else { return }
        let pid = front.processIdentifier
        let focus = rules.focusAfterSwitch(
            owner: owner(of: front), windowProfiles: windows.profiles(of: pid), focusedProfile: windows.focusedProfile(of: pid),
            active: profile)
        switch focus {
        case .keep: break
        case .raiseHere: windows.raise(pid, in: profile)
        case .handOff:
            bringForward(windows.frontApp(in: profile) ?? NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first)
        }
    }

    /// Forgets windows that closed since Dockry last looked, before deciding what opening
    /// an app does: its last window in this profile may be gone.
    func forgetClosedWindows() {
        if windows.forgetClosed() {
            windowChanges += 1
        }
    }

    /// The app's windows in the active profile, for the dock's window list.
    func windows(of app: NSRunningApplication) -> [AppWindows.Window] {
        let all = AppWindows.shared.windows(of: app.processIdentifier)
        guard isEnabled else { return all }
        return all.filter { windows.isIn(store.active.name, $0.element) }
    }

    private func updateMinimized() {
        var counts: [pid_t: Int] = [:]
        // Only apps with a minimized window are asked for their windows.
        for pid in AppWindows.shared.minimizedCounts.keys {
            guard let app = NSRunningApplication(processIdentifier: pid) else { continue }
            let count = windows(of: app).filter(\.isMinimized).count
            if count > 0 {
                counts[pid] = count
            }
        }
        if counts != minimizedCounts {
            minimizedCounts = counts
        }
    }

    /// macOS may refuse to bring an app forward for an app that isn't the active one.
    private func bringForward(_ app: NSRunningApplication?) {
        guard let app, !app.activate() else { return }
        NSLog("Dockry: macOS didn't bring \(app.localizedName ?? "an app") forward")
    }

    /// Opens a new window of the app in the active profile, as its New Window (⌘N) would,
    /// and brings it forward once the window is open. An app that can't open one (it has
    /// no New Window item, or the item opened none) has its front window brought here
    /// instead: it would come forward with every window off screen.
    func openWindow(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        let active = store.active.name
        let name = app.localizedName ?? "an app"
        guard let item = AppWindows.newWindowItem(in: app) else {
            NSLog("Dockry windows: \(name) has no New Window item; bringing its window to \(active)")
            bringWindow(of: app, to: active)
            return
        }
        openingWindow[pid] = Date()
        AXUIElementPerformAction(item, kAXPressAction as CFString)
        Task { [weak self] in
            for _ in 0..<20 where self?.windows.profiles(of: pid).contains(active) != true {
                try? await Task.sleep(for: .milliseconds(100))
            }
            // Unless the user has switched meanwhile.
            guard let self, store.active.name == active else { return }
            if windows.profiles(of: pid).contains(active) {
                bringForward(app)
                windows.raise(pid, in: active)
            } else {
                NSLog("Dockry windows: \(name)'s New Window opened none in \(active); bringing its window there")
                bringWindow(of: app, to: active)
            }
        }
    }

    private func bringWindow(of app: NSRunningApplication, to profile: String) {
        if windows.bringFrontWindow(of: app.processIdentifier, to: profile) {
            windowChanges += 1
        }
        bringForward(app)
        windows.raise(app.processIdentifier, in: profile)
    }

    /// An app came forward: Dockry's dock, ⌘Tab, Raycast, a link or a click. The same
    /// rule for every way in (ProfileAppRules.activated), so nothing is guessed from timing.
    private func activated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        // Only apps: menu bar apps and macOS's own dialogs (a password prompt) come forward
        // too, and belong to no profile.
        guard app != .current, app.activationPolicy == .regular else { return }
        forgetClosedWindows()
        // Its new window is on the way (openWindow); the app comes forward before it's there.
        if let asked = openingWindow[pid], Date().timeIntervalSince(asked) < 3 { return }
        let active = store.active.name
        let activation = rules.activated(
            owner: owner(of: app), windowProfiles: windows.profiles(of: pid), focusedProfile: windows.focusedProfile(of: pid),
            active: active)
        switch activation {
        case .nothing: break
        case .switchTo(let profile): switchToProfile?(profile)
        case .raiseHere: windows.raise(pid, in: active)
        case .openWindowHere:
            NSLog("Dockry windows: \(app.localizedName ?? "an app") came forward with no window in \(active); opening one")
            openWindow(app)
        }
    }

    /// Puts parked windows back before Dockry quits; the next launch parks them again.
    func restoreWindows() {
        windows.unparkAll()
    }

    private func assign(_ app: NSRunningApplication, to profile: String) {
        guard app != .current else { return }
        owners[app.processIdentifier] = profile
        save()
    }

    private func save() {
        // By process: with copies per profile, one app can be in several.
        let entries = owners.map { pid, profile in
            AppOwnership.Entry(pid: pid, launchedAt: NSRunningApplication(processIdentifier: pid)?.launchDate, profile: profile)
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(AppOwnership(entries: entries)), forKey: Self.savedOwnersKey)
    }
}

/// Which apps are playing sound, from Core Audio's list of processes using audio.
enum AudioOutput {
    /// The apps (not their helper processes) with sound going out right now.
    static func appPIDs() -> Set<pid_t> {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }
        var result = Set<pid_t>()
        for process in processes where value(UInt32.self, kAudioProcessPropertyIsRunningOutput, of: process) == 1 {
            if let pid = value(pid_t.self, kAudioProcessPropertyPID, of: process) {
                result.insert(responsiblePID(for: pid))
            }
        }
        return result
    }

    private static func value<Value>(_ type: Value.Type, _ selector: AudioObjectPropertySelector, of object: AudioObjectID) -> Value? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Value>.size)
        let pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    /// Sound often comes from a helper (a browser tab's process, say); this is the app it
    /// works for. The function is private to macOS but long-standing, and used by Activity
    /// Monitor; without it, the helper's own process is used.
    private static func responsiblePID(for pid: pid_t) -> pid_t {
        typealias Responsible = @convention(c) (pid_t) -> pid_t
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return pid }
        let responsible = unsafeBitCast(symbol, to: Responsible.self)(pid)
        return responsible > 0 ? responsible : pid
    }
}
