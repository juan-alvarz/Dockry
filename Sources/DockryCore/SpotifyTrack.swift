import Foundation

/// What Spotify is playing. Nil (no track) means Spotify is stopped or not running.
public struct SpotifyTrack: Equatable {
    public var title: String
    public var artist: String
    public var isPlaying: Bool
    public var artworkURL: URL?

    public init(title: String, artist: String, isPlaying: Bool, artworkURL: URL? = nil) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.artworkURL = artworkURL
    }

    /// Name of the distributed notification Spotify posts whenever playback changes.
    public static let playbackChangedNotification = "com.spotify.client.PlaybackStateChanged"

    /// From the notification's userInfo. It has no artwork; `appleScript` provides that.
    public init?(playbackInfo: [String: Any]) {
        guard let state = playbackInfo["Player State"] as? String, state != "Stopped",
              let title = playbackInfo["Name"] as? String
        else { return nil }
        self.init(title: title, artist: playbackInfo["Artist"] as? String ?? "", isPlaying: state == "Playing")
    }

    /// Asks Spotify for the current track without launching it. Prints the player state,
    /// title, artist and artwork URL on separate lines, or nothing when Spotify isn't playing.
    public static let appleScript = """
        if application id "com.spotify.client" is running then
            tell application id "com.spotify.client"
                if player state is not stopped then
                    set t to current track
                    return (player state as text) & linefeed & (name of t) & linefeed & (artist of t) & linefeed & (artwork url of t)
                end if
            end tell
        end if
        return ""
        """

    /// From what `appleScript` prints.
    public init?(appleScriptOutput output: String) {
        let lines = output.components(separatedBy: "\n")
        guard lines.count >= 4, lines[0] == "playing" || lines[0] == "paused" else { return nil }
        self.init(
            title: lines[1], artist: lines[2], isPlaying: lines[0] == "playing",
            artworkURL: URL(string: lines[3].trimmingCharacters(in: .whitespaces)))
    }
}
