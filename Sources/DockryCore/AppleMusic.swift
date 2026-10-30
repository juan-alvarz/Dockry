import Foundation

/// What the Music app is playing. Nil (no track) means Music is stopped or not running.
public struct MusicTrack: Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    /// The track's persistent ID as Music's AppleScript writes it: 16 hex digits.
    public var persistentID: String?

    public init(title: String, artist: String, album: String = "", isPlaying: Bool, persistentID: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.persistentID = persistentID
    }

    public static let bundleID = "com.apple.Music"
    /// Name of the distributed notification Music posts whenever playback changes.
    public static let playbackChangedNotification = "com.apple.Music.playerInfo"

    /// From the notification's userInfo, which has no artwork.
    public init?(playerInfo: [String: Any]) {
        guard let state = playerInfo["Player State"] as? String, state != "Stopped",
              let title = playerInfo["Name"] as? String
        else { return nil }
        // The notification gives the ID as a (signed) 64-bit number.
        let id = (playerInfo["PersistentID"] as? NSNumber).map { String(format: "%016llX", UInt64(bitPattern: $0.int64Value)) }
        self.init(
            title: title, artist: playerInfo["Artist"] as? String ?? "", album: playerInfo["Album"] as? String ?? "",
            isPlaying: state == "Playing", persistentID: id)
    }

    /// Asks Music for the current track without launching it. Prints the player state,
    /// title, artist, album and persistent ID on separate lines, or nothing when stopped.
    public static let appleScript = """
        if application id "com.apple.Music" is running then
            tell application id "com.apple.Music"
                if player state is not stopped then
                    set t to current track
                    return (player state as text) & linefeed & (name of t) & linefeed & (artist of t) & linefeed & (album of t) & linefeed & (persistent ID of t)
                end if
            end tell
        end if
        return ""
        """

    /// From what `appleScript` prints.
    public init?(appleScriptOutput output: String) {
        let lines = output.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 5, lines[0] == "playing" || lines[0] == "paused" else { return nil }
        self.init(
            title: lines[1], artist: lines[2], album: lines[3], isPlaying: lines[0] == "playing",
            persistentID: lines[4].isEmpty ? nil : lines[4])
    }

    /// Writes the current track's album art, as Music stores it, to `path`, and prints the
    /// path; prints nothing when there's no track or no art. The file writing happens
    /// outside the `tell` block, which Music wouldn't understand.
    public static func artworkScript(writingTo path: String) -> String {
        """
        if application id "com.apple.Music" is not running then return ""
        tell application id "com.apple.Music"
            if player state is stopped then return ""
            if (count of artworks of current track) is 0 then return ""
            set d to raw data of artwork 1 of current track
        end tell
        set f to open for access (POSIX file "\(appleScriptEscaped(path))") with write permission
        set eof f to 0
        write d to f
        close access f
        return "\(appleScriptEscaped(path))"
        """
    }
}

/// Music's playback position, volume and modes, read while the player popover is open.
public struct MusicPlayback: Equatable {
    public enum Repeat: String, Equatable {
        case off, all, one

        /// What clicking the repeat button goes to, as in Music: off, all, one, off.
        public var next: Repeat {
            switch self {
            case .off: .all
            case .all: .one
            case .one: .off
            }
        }
    }

    public var position: Double
    public var duration: Double
    /// 0–100.
    public var volume: Int
    public var isShuffling: Bool
    public var repeatMode: Repeat

    public init(position: Double, duration: Double, volume: Int, isShuffling: Bool, repeatMode: Repeat) {
        self.position = position
        self.duration = duration
        self.volume = volume
        self.isShuffling = isShuffling
        self.repeatMode = repeatMode
    }

    /// Prints position and duration in whole seconds (so the output doesn't depend on the
    /// locale's decimal separator), volume, shuffle and repeat, one per line.
    public static let appleScript = """
        if application id "com.apple.Music" is not running then return ""
        tell application id "com.apple.Music"
            if player state is stopped then return ""
            set p to player position
            set d to duration of current track
            set v to sound volume
            set s to shuffle enabled
            set r to song repeat
        end tell
        return ((p as integer) as text) & linefeed & ((d as integer) as text) & linefeed & (v as text) & linefeed & (s as text) & linefeed & (r as text)
        """

    public init?(appleScriptOutput output: String) {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 5, let position = Double(lines[0]), let duration = Double(lines[1]),
              let volume = Int(lines[2]), let repeatMode = Repeat(rawValue: lines[4])
        else { return nil }
        self.init(position: position, duration: duration, volume: volume, isShuffling: lines[3] == "true", repeatMode: repeatMode)
    }
}

/// A song from the user's Music library.
public struct MusicSearchResult: Equatable, Identifiable {
    public let persistentID: String
    public let title: String
    public let artist: String
    public let album: String

    public var id: String { persistentID }

    public init(persistentID: String, title: String, artist: String, album: String) {
        self.persistentID = persistentID
        self.title = title
        self.artist = artist
        self.album = album
    }

    /// Searches the library for songs; prints up to `limit`, one per line, as persistent
    /// ID, title, artist and album separated by tabs.
    public static func searchScript(_ query: String, limit: Int = 20) -> String {
        """
        tell application id "com.apple.Music"
            set found to (search library playlist 1 for "\(appleScriptEscaped(query))" only songs)
            set n to count of found
            if n > \(limit) then set n to \(limit)
            set out to ""
            repeat with i from 1 to n
                set t to item i of found
                set out to out & (persistent ID of t) & tab & (name of t) & tab & (artist of t) & tab & (album of t) & linefeed
            end repeat
            return out
        end tell
        """
    }

    public static func parseSearch(_ output: String) -> [MusicSearchResult] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4, isPersistentID(fields[0]) else { return nil }
            return MusicSearchResult(persistentID: fields[0], title: fields[1], artist: fields[2], album: fields[3])
        }
    }

    /// Plays a library song by persistent ID; nil for anything that isn't one, so nothing
    /// else can end up in the script.
    public static func playScript(persistentID: String) -> String? {
        guard isPersistentID(persistentID) else { return nil }
        return #"play (first track of library playlist 1 whose persistent ID is "\#(persistentID)")"#
    }

    static func isPersistentID(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 16 && text.allSatisfy(\.isHexDigit)
    }
}

/// `text` inside an AppleScript string literal: backslashes and quotes escaped, line breaks
/// and tabs as spaces.
func appleScriptEscaped(_ text: String) -> String {
    text.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\t", with: " ")
}
