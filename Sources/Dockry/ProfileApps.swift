import AppKit
import Combine
import CoreAudio
import DockryCore

/// Gives each profile its own open apps, like the workspaces of Linux desktops: an app
/// belongs to the profile that was active when it opened, and switching profiles hides the
/// other profiles' apps and shows the new one's. Finder is in every profile.
///
/// Profiles with fresh apps (Profile.freshApps) always keep theirs apart, even with the
/// setting off: their own copies never show in another profile nor others' in them, and
/// bringing one forward from elsewhere switches to its profile.
@MainActor
final class ProfileApps: ObservableObject {
    enum Mode {
        /// Each app is in one profile. Bringing one forward from another profile (the dock,
        /// ⌘Tab, a link) moves it to the profile you're in.
        case apps
        /// Each window is in one profile (ProfileWindows), so an app can be in several.
        /// Clicking an app in the dock opens a window of its own in the profile (⌘N), and
        /// bringing forward an app whose windows are all elsewhere switches to their profile.
        case windows
    }

    /// The profile each open app belongs to, by process.
    @Published private(set) var owners: [pid_t: String] = [:]
    /// The open apps playing sound right now, while keeping apps apart.
    @Published private(set) var playingPIDs: Set<pid_t> = []

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled {
                show(store.active.name)
            } else {
                windows.unparkAll()
                // Nothing stays hidden once apps are shared again.
                for app in NSWorkspace.shared.runningApplications where app.isHidden && owners[app.processIdentifier] != nil {
                    app.unhide()
                }
            }
            updateAudioWatch()
        }
    }

    var mode = Mode.apps {
        didSet {
            guard mode != oldValue else { return }
            if oldValue == .windows {
                windows.unparkAll()
            }
            show(store.active.name)
        }
    }
    /// Bumped when windows change profile, for the dock to follow.
    @Published private(set) var windowChanges = 0
    /// Switches to a profile, as the user would.
    var switchToProfile: ((String) -> Void)?

    private let store: ProfileStore
    private let windows = ProfileWindows()
    /// Apps hidden because they're on the other side of a fresh profile, to show again
    /// while keeping apps apart is off.
    private var hiddenForFresh: Set<pid_t> = []
    /// Apps that were just asked for a window of their own, which brings them forward
    /// before the window exists.
    private var openingWindow: [pid_t: Date] = [:]
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
                self?.windows.forget(app.processIdentifier)
                self?.save()
            }
            .store(in: &subscriptions)
        apps(NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] app in
                guard let self, Date().timeIntervalSince(switchedAt) > 1, let owner = owner(of: app) else { return }
                let active = store.active.name
                if owner != active && (isFresh(owner) || isFresh(active)) {
                    switchToProfile?(owner)
                    return
                }
                guard isEnabled else { return }
                switch mode {
                case .apps where owner != active:
                    assign(app, to: active)
                case .windows:
                    if let asked = openingWindow[app.processIdentifier], Date().timeIntervalSince(asked) < 3 { return }
                    let profiles = windows.profiles(of: app)
                    if profiles.contains(active) {
                        windows.park(app, except: active)
                        windows.raise(app, in: active)
                    } else if let other = profiles.sorted().first {
                        switchToProfile?(other)
                    }
                default:
                    break
                }
            }
            .store(in: &subscriptions)
        AppWindows.shared.windowCreated = { [weak self] window in
            guard let self, isEnabled, mode == .windows else { return }
            var pid: pid_t = 0
            AXUIElementGetPid(window, &pid)
            guard let app = NSRunningApplication(processIdentifier: pid), let owner = owner(of: app) else { return }
            let active = store.active.name
            // A fresh profile's copy never has windows elsewhere, nor another's in it.
            let profile = isFresh(owner) || isFresh(active) ? owner : active
            windows.adopt(window, into: profile)
            // An app that opened a window by itself (a link, say) shows the others' too.
            if profile == active {
                windows.park(app, except: active)
            }
            windowChanges += 1
        }
        ProfileWindows.rescueParkedWindows()
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

    /// Whether the dock shows the app in the active profile: with windows per profile, when
    /// it has windows there (or, without any, when it opened there).
    func isShown(_ app: NSRunningApplication) -> Bool {
        guard let owner = owner(of: app) else { return true }
        let active = store.active.name
        if isFresh(owner) || isFresh(active) { return owner == active }
        guard isEnabled else { return true }
        if mode == .windows {
            let profiles = windows.profiles(of: app)
            if !profiles.isEmpty { return profiles.contains(store.active.name) }
        }
        return owner == store.active.name
    }

    /// Whether the app is a fresh profile's own copy.
    func isFreshCopy(_ app: NSRunningApplication) -> Bool {
        owner(of: app).map(isFresh) == true
    }

    private func isFresh(_ profile: String) -> Bool {
        store.library.profiles.first { $0.name == profile }?.freshApps == true
    }

    /// Opens a window of the app's own in the active profile, as ⌘N would, with its windows
    /// in other profiles parked first. An app without a New Window item has its windows
    /// moved here instead.
    func openWindow(_ app: NSRunningApplication) {
        let active = store.active.name
        openingWindow[app.processIdentifier] = Date()
        if let item = AppWindows.newWindowItem(in: app) {
            windows.park(app, except: active)
            app.unhide()
            app.activate()
            // Once it's in front, so the window opens in front.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                AXUIElementPerformAction(item, kAXPressAction as CFString)
            }
        } else {
            windows.move(app, to: active)
            windowChanges += 1
            app.unhide()
            app.activate()
        }
    }

    /// Puts parked windows back before Dockry quits.
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
        guard isEnabled else {
            // Only fresh profiles' apps are kept apart.
            for app in apps where isShown(app) && hiddenForFresh.remove(app.processIdentifier) != nil {
                app.unhide()
            }
            for app in apps where !isShown(app) && !app.isHidden {
                app.hide()
                hiddenForFresh.insert(app.processIdentifier)
            }
            windowChanges += 1
            return
        }
        if mode == .windows {
            windows.show(profile, apps: apps, owner: owner(of:))
            windowChanges += 1
            return
        }
        // Showing first, so macOS has the new profile's apps to bring forward as the others hide.
        for app in apps where owner(of: app) == profile && app.isHidden {
            app.unhide()
        }
        for app in apps where !isShown(app) && !app.isHidden {
            app.hide()
        }
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
