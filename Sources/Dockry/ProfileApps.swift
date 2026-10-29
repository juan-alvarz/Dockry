import AppKit
import Combine
import CoreAudio
import DockryCore

/// Gives each profile its own open apps, like the workspaces of Linux desktops: an app
/// belongs to the profile that was active when it opened, and switching profiles hides the
/// other profiles' apps and shows the new one's. Bringing an app forward while in another
/// profile (from the dock, ⌘Tab, a link) moves it to that profile. Finder is in every profile.
@MainActor
final class ProfileApps: ObservableObject {
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
                // Nothing stays hidden once apps are shared again.
                for app in NSWorkspace.shared.runningApplications where app.isHidden && owners[app.processIdentifier] != nil {
                    app.unhide()
                }
            }
            updateAudioWatch()
        }
    }

    private let store: ProfileStore
    private var subscriptions: Set<AnyCancellable> = []
    /// Switching hides and shows apps, and macOS activates whichever comes forward; for a
    /// moment those activations aren't the user moving an app here.
    private var switchedAt = Date.distantPast
    private var audioTimer: Timer?
    private static let savedOwnersKey = "appProfiles"
    private static let sharedApps: Set<String> = ["com.apple.finder"]

    init(store: ProfileStore) {
        self.store = store
        // Apps open before Dockry started go back where they were, by bundle identifier.
        let saved = UserDefaults.standard.dictionary(forKey: Self.savedOwnersKey) as? [String: String] ?? [:]
        for app in NSWorkspace.shared.runningApplications {
            assign(app, to: app.bundleIdentifier.flatMap { saved[$0] } ?? store.active.name)
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
            .sink { [weak self] app in
                guard let self, isEnabled, Date().timeIntervalSince(switchedAt) > 1,
                      let owner = owners[app.processIdentifier], owner != store.active.name
                else { return }
                assign(app, to: store.active.name)
            }
            .store(in: &subscriptions)
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

    /// Whether the dock shows the app in the active profile.
    func isShown(_ app: NSRunningApplication) -> Bool {
        !isEnabled || owner(of: app) == nil || owner(of: app) == store.active.name
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
        guard isEnabled else { return }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != .current }
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
        var saved: [String: String] = [:]
        for (pid, owner) in owners {
            if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
                saved[bundleID] = owner
            }
        }
        UserDefaults.standard.set(saved, forKey: Self.savedOwnersKey)
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

/// Each profile's desktop picture. A profile without one shows the user's own, which is
/// saved before the first profile's picture replaces it.
@MainActor
enum Wallpapers {
    private static let savedKey = "ownWallpapers"

    static func switched(from previous: Profile?, to profile: Profile) {
        guard profile.wallpaper != previous?.wallpaper || previous == nil else { return }
        if let wallpaper = profile.wallpaper {
            if previous?.wallpaper == nil {
                saveOwn(replacing: previous != nil)
            }
            set { _ in URL(fileURLWithPath: wallpaper) }
        } else if previous != nil {
            let saved = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: String] ?? [:]
            set { screen in saved[screen].map { URL(fileURLWithPath: $0) } }
        }
    }

    /// Remembers the pictures showing now as the user's own. At launch, only if none are
    /// saved yet: what's showing may be a profile's.
    private static func saveOwn(replacing: Bool) {
        if !replacing && UserDefaults.standard.dictionary(forKey: savedKey) != nil { return }
        var saved: [String: String] = [:]
        for screen in NSScreen.screens {
            if let id = screen.displayID, let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                saved[String(id)] = url.path
            }
        }
        UserDefaults.standard.set(saved, forKey: savedKey)
    }

    private static func set(_ picture: (String) -> URL?) {
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let url = picture(String(id)),
                  url != NSWorkspace.shared.desktopImageURL(for: screen)
            else { continue }
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
            } catch {
                NSLog("Dockry: couldn't set the desktop picture to \(url.path): \(error)")
            }
        }
    }
}
