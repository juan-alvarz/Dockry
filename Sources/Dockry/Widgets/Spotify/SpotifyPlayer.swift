import AppKit
import Combine
import DockryCore

/// Follows what Spotify is playing and controls it. Track changes come from the notification
/// Spotify broadcasts, which needs no permission; artwork and the controls go through
/// AppleScript, so macOS asks once to let Dockry control Spotify.
@MainActor
final class SpotifyPlayer: ObservableObject {
    @Published private(set) var track: SpotifyTrack?
    /// Position, volume and modes; only kept up to date while the player popover is open.
    @Published private(set) var playback: SpotifyPlayback?

    private static let bundleID = "com.spotify.client"
    private var subscriptions: Set<AnyCancellable> = []
    private var playbackTimer: Timer?
    private var volumeChange: Task<Void, Never>?

    init() {
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name(SpotifyTrack.playbackChangedNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let info = notification.userInfo as? [String: Any] ?? [:]
                self?.update(SpotifyTrack(playbackInfo: info))
            }
            .store(in: &subscriptions)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .filter { $0.bundleIdentifier == Self.bundleID }
            .sink { [weak self] _ in self?.track = nil }
            .store(in: &subscriptions)

        // The notification only arrives on the next change, so ask once for what's playing now.
        if isSpotifyRunning {
            refresh()
        }
    }

    /// Also starts Spotify (and playback) when it isn't running.
    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    /// Plays a song by its Spotify URI, in the Spotify app (which stays in the background).
    func play(uri: String) {
        send("play track \"\(uri.replacingOccurrences(of: "\"", with: ""))\"")
    }

    /// Brings the Spotify app forward, the one thing here that does.
    func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func seek(to seconds: Double) {
        playback?.position = seconds
        send("set player position to \(Int(seconds))")
    }

    /// Dragging the volume slider calls this many times a second; only the value it rests
    /// on goes to Spotify, instead of one osascript process per step.
    func setVolume(_ volume: Int) {
        playback?.volume = volume
        volumeChange?.cancel()
        volumeChange = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            send("set sound volume to \(volume)")
        }
    }

    func toggleShuffle() {
        guard let playback else { return }
        self.playback?.isShuffling.toggle()
        send("set shuffling to \(!playback.isShuffling)")
    }

    func toggleRepeat() {
        guard let playback else { return }
        self.playback?.isRepeating.toggle()
        send("set repeating to \(!playback.isRepeating)")
    }

    /// Asks Spotify for the position every second, for the popover's progress bar.
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

    private func refreshPlayback() {
        if let sample = ScreenshotHook.spotifyPlayback {
            playback = playback ?? SpotifyPlayback(appleScriptOutput: sample)
            return
        }
        guard isSpotifyRunning else {
            playback = nil
            return
        }
        Task {
            let output = await AppleScript.run(SpotifyPlayback.appleScript)
            playback = output.flatMap(SpotifyPlayback.init(appleScriptOutput:))
        }
    }

    private var isSpotifyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    private func update(_ newTrack: SpotifyTrack?) {
        guard var newTrack else {
            track = nil
            return
        }
        let isSameSong = newTrack.title == track?.title && newTrack.artist == track?.artist
        newTrack.artworkURL = isSameSong ? track?.artworkURL : ScreenshotHook.spotifyArtwork
        track = newTrack
        // The notification has no artwork; ask Spotify for it.
        if newTrack.artworkURL == nil && isSpotifyRunning {
            refresh()
        }
    }

    private func refresh() {
        Task {
            guard let output = await AppleScript.run(SpotifyTrack.appleScript) else { return }
            track = SpotifyTrack(appleScriptOutput: output)
        }
    }

    /// Spotify plays from the background: AppleScript would open a stopped Spotify in front,
    /// so it's started hidden first, and if it still comes forward (playing a song can do
    /// that), it's hidden again. "Open Spotify" in the player is how to see it.
    private func send(_ command: String) {
        Task {
            let wasRunning = isSpotifyRunning
            // Unless the user is in Spotify already.
            let wasInFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.bundleID
            if !wasRunning {
                await launchHidden()
            }
            _ = await AppleScript.run("tell application id \"\(Self.bundleID)\" to \(command)")
            for _ in 0..<(wasInFront ? 0 : wasRunning ? 2 : 10) {
                try? await Task.sleep(for: .milliseconds(300))
                if let spotify = NSWorkspace.shared.frontmostApplication, spotify.bundleIdentifier == Self.bundleID {
                    spotify.hide()
                    break
                }
            }
        }
    }

    private func launchHidden() async {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        // Its AppleScript isn't ready the moment it launches.
        try? await Task.sleep(for: .seconds(2))
    }
}

/// Runs AppleScript in an `osascript` process, so a slow or hung app can't freeze the dock
/// the way NSAppleScript on the main thread would.
enum AppleScript {
    /// The script's output, or nil if it failed (e.g. the user didn't allow automation).
    static func run(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            // Reading after exit is fine for these few lines; output beyond the pipe's buffer
            // (64 KB) would block osascript before it exits.
            process.terminationHandler = { process in
                let data = output.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
