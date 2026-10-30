import AppKit
import Combine
import DockryCore

/// Follows what the Music app is playing and controls it, like SpotifyPlayer: track changes
/// come from the notification Music broadcasts, which needs no permission; art, controls
/// and search go through AppleScript, so macOS asks once to let Dockry control Music.
@MainActor
final class MusicPlayer: ObservableObject {
    @Published private(set) var track: MusicTrack?
    /// The current track's album art, as a file Music wrote it to.
    @Published private(set) var artworkURL: URL?
    /// Position, volume and modes; only kept up to date while the player popover is open.
    @Published private(set) var playback: MusicPlayback?

    private static let bundleID = MusicTrack.bundleID
    private var subscriptions: Set<AnyCancellable> = []
    private var playbackTimer: Timer?
    private var volumeChange: Task<Void, Never>?

    init() {
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name(MusicTrack.playbackChangedNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.update(MusicTrack(playerInfo: notification.userInfo as? [String: Any] ?? [:]))
            }
            .store(in: &subscriptions)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .filter { $0.bundleIdentifier == Self.bundleID }
            .sink { [weak self] _ in self?.update(nil) }
            .store(in: &subscriptions)

        // The notification only arrives on the next change, so ask once for what's playing,
        // but never launch Music (or ask for permission) just to find out.
        if isMusicRunning {
            Task {
                guard let output = await AppleScript.run(MusicTrack.appleScript) else { return }
                update(MusicTrack(appleScriptOutput: output))
            }
        }
    }

    /// Also starts Music (hidden) when it isn't running.
    func playPause() { AppleScript.tell(Self.bundleID, "playpause") }
    func next() { AppleScript.tell(Self.bundleID, "next track") }
    func previous() { AppleScript.tell(Self.bundleID, "previous track") }

    func play(_ result: MusicSearchResult) {
        guard let script = MusicSearchResult.playScript(persistentID: result.persistentID) else { return }
        AppleScript.tell(Self.bundleID, script)
    }

    /// Brings the Music app forward, the one thing here that does.
    func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func seek(to seconds: Double) {
        playback?.position = seconds
        AppleScript.tell(Self.bundleID, "set player position to \(Int(seconds))")
    }

    /// Only the value the volume slider rests on goes to Music.
    func setVolume(_ volume: Int) {
        playback?.volume = volume
        volumeChange?.cancel()
        volumeChange = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            AppleScript.tell(Self.bundleID, "set sound volume to \(volume)")
        }
    }

    func toggleShuffle() {
        guard let playback else { return }
        self.playback?.isShuffling.toggle()
        AppleScript.tell(Self.bundleID, "set shuffle enabled to \(!playback.isShuffling)")
    }

    /// Off, all, one, off, as Music's own button.
    func cycleRepeat() {
        guard let playback else { return }
        let next = playback.repeatMode.next
        self.playback?.repeatMode = next
        AppleScript.tell(Self.bundleID, "set song repeat to \(next.rawValue)")
    }

    func search(_ query: String) async -> [MusicSearchResult] {
        guard let output = await AppleScript.run(MusicSearchResult.searchScript(query)) else { return [] }
        return MusicSearchResult.parseSearch(output)
    }

    /// Asks Music for the position every second, for the popover's progress bar.
    func startFollowingPlayback() {
        guard playbackTimer == nil else { return }
        refreshPlayback()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPlayback() }
        }
    }

    func stopFollowingPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    private func refreshPlayback() {
        guard isMusicRunning else {
            playback = nil
            return
        }
        Task {
            let output = await AppleScript.run(MusicPlayback.appleScript)
            playback = output.flatMap(MusicPlayback.init(appleScriptOutput:))
        }
    }

    private func update(_ newTrack: MusicTrack?) {
        let isSameTrack = newTrack?.persistentID != nil && newTrack?.persistentID == track?.persistentID
        track = newTrack
        guard let newTrack, !isSameTrack else {
            if newTrack == nil { artworkURL = nil }
            return
        }
        artworkURL = nil
        guard isMusicRunning, let id = newTrack.persistentID else { return }
        // One file per track, so the artwork cache never shows the previous track's art.
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("dockry-music-\(id)").path
        Task {
            guard let written = await AppleScript.run(MusicTrack.artworkScript(writingTo: path)),
                  !written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  track?.persistentID == id
            else { return }
            artworkURL = URL(fileURLWithPath: path)
        }
    }
}
