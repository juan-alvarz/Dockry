import AppKit
import Combine
import CoreAudio
import DockryCore

/// Gives each profile its own open apps, like the workspaces of Linux desktops. Finder is in
/// every profile.
///
/// Profiles with fresh apps (Profile.freshApps) always keep theirs apart, even with the
/// setting off: their own copies never show in another profile nor others' in them, and
/// bringing one forward from elsewhere switches to its profile.
@MainActor
final class ProfileApps: ObservableObject {
    enum Mode {
        /// Each app is in one profile: the one active when it opened. Switching hides the
        /// other profiles' apps, and bringing one forward from another profile (the dock,
        /// ⌘Tab, a link) moves it to the profile you're in.
        case apps
        /// Each window is in one profile (ProfileWindows): the one active when it opened.
        /// Switching parks the other profiles' windows off screen and hides apps with no
        /// window in the profile. An app is in the profiles it has windows in, and clicking it in the dock where it has
        /// none opens a new window of it there (its New Window, ⌘N). Bringing forward an app
        /// whose windows are all in other profiles switches to theirs.
        case windows
    }

    /// The profile each open app belongs to, by process.
    @Published private(set) var owners: [pid_t: String] = [:]
    /// The open apps playing sound right now, while keeping apps apart.
    @Published private(set) var playingPIDs: Set<pid_t> = []
    /// Bumped when windows change profile or open, for the dock to follow.
    @Published private(set) var windowChanges = 0

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            if !isEnabled {
                windows.unparkAll()
                unhideAll()
            }
            show(store.active.name)
            updateAudioWatch()
        }
    }

    var mode = Mode.apps {
        didSet {
            guard mode != oldValue else { return }
            // Each mode starts over: window mode hides only apps with no window here, and app mode parks nothing.
            if mode == .windows {
                unhideAll()
            } else {
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
    /// The apps Dockry hid, and only those, to show again: not ones the user hid.
    private var hiddenByDockry: Set<pid_t> = []
    private var subscriptions: Set<AnyCancellable> = []
    /// Switching hides and shows apps, and macOS activates whichever comes forward; for a
    /// moment those activations aren't the user moving an app here.
    private var switchedAt = Date.distantPast
    private var audioTimer: Timer?
    private static let savedOwnersKey = "appProfiles"
    private static let sharedApps: Set<String> = ["com.apple.finder"]

    init(store: ProfileStore) {
        self.store = store
        // Apps open before Dockry started go back where they were, by process.
        let saved = UserDefaults.standard.dictionary(forKey: Self.savedOwnersKey) as? [String: String] ?? [:]
        for app in NSWorkspace.shared.runningApplications {
            assign(app, to: saved[String(app.processIdentifier)] ?? store.active.name)
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
                self?.hiddenByDockry.remove(app.processIdentifier)
                self?.save()
            }
            .store(in: &subscriptions)
        apps(NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] app in
                guard let self, Date().timeIntervalSince(switchedAt) > 2, let owner = owner(of: app) else { return }
                let active = store.active.name
                if owner != active && (isFresh(owner) || isFresh(active)) {
                    switchToProfile?(owner)
                } else if isEnabled && mode == .apps && owner != active {
                    assign(app, to: active)
                } else if isEnabled && mode == .windows {
                    windowsActivated(app)
                }
            }
            .store(in: &subscriptions)
        AppWindows.shared.windowCreated = { [weak self] window in
            guard let self, isEnabled, mode == .windows else { return }
            var pid: pid_t = 0
            AXUIElementGetPid(window, &pid)
            guard let app = NSRunningApplication(processIdentifier: pid), let owner = owner(of: app) else { return }
            windows.adopt(window, pid: pid, into: newWindowProfile(owner: owner))
            windowChanges += 1
        }
        // A renamed or removed profile's apps go to the active profile.
        store.$library
            .receive(on: RunLoop.main)
            .sink { [weak self] library in
                guard let self else { return }
                let names = Set(library.profiles.map(\.name))
                for (pid, owner) in owners where !names.contains(owner) {
                    owners[pid] = library.activeProfileName
                }
            }
            .store(in: &subscriptions)
    }

    /// Whether the dock shows the app in the active profile. In window mode, when it has a
    /// window on this desktop or minimized; an app with no windows at all goes by the
    /// profile it opened in.
    func isShown(_ app: NSRunningApplication) -> Bool {
        guard let owner = owner(of: app) else { return true }
        let active = store.active.name
        if isFresh(owner) || isFresh(active) { return owner == active }
        guard isEnabled else { return true }
        if mode == .windows {
            let profiles = windows.profiles(of: app.processIdentifier)
            if !profiles.isEmpty { return profiles.contains(active) }
        }
        return owner == active
    }

    /// Whether the app is a fresh profile's own copy.
    func isFreshCopy(_ app: NSRunningApplication) -> Bool {
        owner(of: app).map(isFresh) == true
    }

    private func isFresh(_ profile: String) -> Bool {
        store.library.profiles.first { $0.name == profile }?.freshApps == true
    }

    /// A new window goes to the active profile, unless a fresh profile is involved: its
    /// copies' windows are always its own, and others' never are.
    private func newWindowProfile(owner: String) -> String {
        let active = store.active.name
        return isFresh(owner) || isFresh(active) ? owner : active
    }

    /// Opens a new window of the app in the active profile, as its New Window (⌘N) would,
    /// for an app whose windows are all in other profiles. It comes forward once the window
    /// is open, so the other profiles' parked windows don't come along. An app without a New
    /// Window item has its windows moved here instead.
    func openWindow(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        openingWindow[pid] = Date()
        if hiddenByDockry.remove(pid) != nil {
            app.unhide()
        }
        guard let item = AppWindows.newWindowItem(in: app) else {
            windows.move(pid, to: store.active.name)
            windowChanges += 1
            app.activate()
            return
        }
        AXUIElementPerformAction(item, kAXPressAction as CFString)
        let active = store.active.name
        Task { [weak self] in
            for _ in 0..<20 where self?.windows.profiles(of: pid).contains(active) != true {
                try? await Task.sleep(for: .milliseconds(100))
            }
            app.activate()
            self?.windows.raise(pid, in: active)
        }
    }

    /// An app came forward (⌘Tab, a click on one of its windows, a link): with windows in
    /// this profile, one of those comes forward; with all of them elsewhere, Dockry switches
    /// to their profile.
    private func windowsActivated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        if let asked = openingWindow[pid], Date().timeIntervalSince(asked) < 3 { return }
        let active = store.active.name
        let profiles = windows.profiles(of: pid)
        if profiles.contains(active) {
            windows.raise(pid, in: active)
        } else if let other = profiles.sorted().first {
            switchToProfile?(other)
        }
    }

    /// Puts parked windows back before Dockry quits; the next launch parks them again.
    func restoreWindows() {
        windows.unparkAll()
    }

    /// The profile an app belongs to; nil for apps in every profile.
    func owner(of app: NSRunningApplication) -> String? {
        app.bundleIdentifier.map(Self.sharedApps.contains) == true ? nil : owners[app.processIdentifier]
    }

    /// The profiles with an app playing sound.
    var playingProfiles: Set<String> {
        Set(playingPIDs.compactMap { pid in NSRunningApplication(processIdentifier: pid).flatMap(owner(of:)) })
    }

    /// Shows the profile's apps and hides the others', after switching to it.
    func show(_ profile: String) {
        switchedAt = Date()
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != .current }
        guard isEnabled && mode == .apps else {
            // Fresh profiles' apps are hidden from the others' and theirs from them.
            let apart = apps.filter { owner(of: $0) != nil && isFreshCopy($0) != isFresh(profile) }
            // The rest share windows, or park those of other profiles. Apps with no window
            // here hide too, as Mission Control still shows parked windows.
            var away = apart
            if isEnabled {
                let shared = apps.filter { !apart.contains($0) && owner(of: $0) != nil }
                windows.scan(shared) { [self] in owner(of: $0) }
                windows.show(profile, apps: shared)
                away += shared.filter { !isShown($0) }
                windowChanges += 1
            }
            for app in apps where !away.contains(app) && hiddenByDockry.remove(app.processIdentifier) != nil {
                app.unhide()
            }
            hide(away, keeping: apps.filter { !away.contains($0) })
            return
        }
        // Showing first, so macOS has the new profile's apps to bring forward as the others hide.
        for app in apps where isShown(app) && hiddenByDockry.remove(app.processIdentifier) != nil {
            app.unhide()
        }
        hide(apps.filter { !isShown($0) }, keeping: apps.filter(isShown))
    }

    /// Hides apps so that none comes back: when the app in front hides, macOS brings the
    /// next one forward, and if that's one being hidden (hiding takes a moment), coming
    /// forward shows it again. So an app that stays comes forward first (one of `keeping`,
    /// or Finder), and apps that didn't hide are hidden again.
    private func hide(_ apps: [NSRunningApplication], keeping: [NSRunningApplication]) {
        let apps = apps.filter { !$0.isHidden }
        guard !apps.isEmpty else { return }
        hiddenByDockry.formUnion(apps.map(\.processIdentifier))
        let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        let front = keeping.first { $0 != finder } ?? finder
        Task { [weak self] in
            if let front, let frontmost = NSWorkspace.shared.frontmostApplication, apps.contains(frontmost) {
                front.activate()
                var waited = 0
                while NSWorkspace.shared.frontmostApplication != front && waited < 10 {
                    try? await Task.sleep(for: .milliseconds(50))
                    waited += 1
                }
            }
            for _ in 0..<3 {
                // Unless the user switched back meanwhile, which takes them off the list.
                let left = apps.filter { !$0.isHidden && !$0.isTerminated && self?.hiddenByDockry.contains($0.processIdentifier) == true }
                guard !left.isEmpty else { break }
                left.forEach { $0.hide() }
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    /// Shows the apps Dockry hid. Not by whether they're hidden now: hiding takes a moment.
    private func unhideAll() {
        for pid in hiddenByDockry {
            NSRunningApplication(processIdentifier: pid)?.unhide()
        }
        hiddenByDockry = []
    }

    private func assign(_ app: NSRunningApplication, to profile: String) {
        guard app != .current else { return }
        owners[app.processIdentifier] = profile
        save()
    }

    private func save() {
        // By process: with copies per profile, one app can be in several.
        UserDefaults.standard.set(
            Dictionary(uniqueKeysWithValues: owners.map { (String($0.key), $0.value) }), forKey: Self.savedOwnersKey)
    }

    // MARK: Sound

    private func updateAudioWatch() {
        audioTimer?.invalidate()
        audioTimer = nil
        playingPIDs = []
        guard isEnabled else { return }
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
