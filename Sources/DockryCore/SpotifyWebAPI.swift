import Foundation

/// A song found by searching Spotify.
public struct SpotifySearchResult: Equatable, Identifiable {
    /// The Spotify URI, like spotify:track:…, which the Spotify app can play.
    public let uri: String
    public let title: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?

    public var id: String { uri }

    public init(uri: String, title: String, artist: String, album: String, artworkURL: URL?) {
        self.uri = uri
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
    }
}

public struct SpotifyToken: Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date
}

/// Requests and responses for the parts of the Spotify Web API Dockry uses: signing in with
/// PKCE (no client secret, so it's safe in an app) and searching for songs. Playback itself
/// goes through the Spotify app's AppleScript, which also works without Premium.
public enum SpotifyWebAPI {
    /// Registered as Dockry's URL scheme in Info.plist.
    public static let redirectURI = "dockry://spotify-callback"

    public static func authorizeURL(clientID: String, codeChallenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            // No scope: searching needs none.
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    /// The authorization code from the callback URL, if `state` matches the sign-in we started.
    public static func authorizationCode(fromCallback url: URL, state: String) -> String? {
        guard url.absoluteString.hasPrefix(redirectURI),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == state
        else { return nil }
        return items.first { $0.name == "code" }?.value
    }

    public static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!

    public static func tokenRequestBody(clientID: String, code: String, codeVerifier: String) -> Data {
        formEncoded([
            ("grant_type", "authorization_code"), ("code", code), ("redirect_uri", redirectURI),
            ("client_id", clientID), ("code_verifier", codeVerifier),
        ])
    }

    public static func refreshRequestBody(clientID: String, refreshToken: String) -> Data {
        formEncoded([("grant_type", "refresh_token"), ("refresh_token", refreshToken), ("client_id", clientID)])
    }

    public static func parseToken(_ data: Data, now: Date) throws -> SpotifyToken {
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return SpotifyToken(
            accessToken: response.access_token, refreshToken: response.refresh_token,
            // A minute early, so a request never goes out with a token about to expire.
            expiresAt: now.addingTimeInterval(response.expires_in - 60))
    }

    public static func searchURL(query: String, limit: Int = 8) -> URL {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        return components.url!
    }

    public static func parseSearch(_ data: Data) throws -> [SpotifySearchResult] {
        struct Response: Decodable {
            struct Tracks: Decodable { let items: [Track] }
            struct Track: Decodable {
                struct Artist: Decodable { let name: String }
                struct Album: Decodable {
                    struct Image: Decodable { let url: URL; let width: Int? }
                    let name: String
                    let images: [Image]
                }
                let uri: String
                let name: String
                let artists: [Artist]
                let album: Album
            }
            let tracks: Tracks
        }
        return try JSONDecoder().decode(Response.self, from: data).tracks.items.map { track in
            // Spotify lists images largest first; the smallest is plenty for a list row.
            let image = track.album.images.min { ($0.width ?? 0) < ($1.width ?? 0) }
            return SpotifySearchResult(
                uri: track.uri, title: track.name,
                artist: track.artists.map(\.name).joined(separator: ", "),
                album: track.album.name, artworkURL: image?.url)
        }
    }

    private static func formEncoded(_ fields: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}

/// Spotify's playback position, volume and modes, read through AppleScript while the
/// player popover is open.
public struct SpotifyPlayback: Equatable {
    public var position: Double
    public var duration: Double
    /// 0–100.
    public var volume: Int
    public var isShuffling: Bool
    public var isRepeating: Bool

    public init(position: Double, duration: Double, volume: Int, isShuffling: Bool, isRepeating: Bool) {
        self.position = position
        self.duration = duration
        self.volume = volume
        self.isShuffling = isShuffling
        self.isRepeating = isRepeating
    }

    /// Prints position and duration in whole seconds (so the output doesn't depend on the
    /// locale's decimal separator), volume, shuffling and repeating, one per line. The
    /// arithmetic happens outside the `tell` block: inside it, AppleScript would send those
    /// commands to Spotify, which doesn't understand them, and the whole script would fail.
    public static let appleScript = """
        if application id "com.spotify.client" is not running then return ""
        tell application id "com.spotify.client"
            if player state is stopped then return ""
            set p to player position
            set d to duration of current track
            set v to sound volume
            set s to shuffling
            set r to repeating
        end tell
        return ((p as integer) as text) & linefeed & ((d div 1000) as text) & linefeed & (v as text) & linefeed & (s as text) & linefeed & (r as text)
        """

    public init?(appleScriptOutput output: String) {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 5, let position = Double(lines[0]), let duration = Double(lines[1]),
              let volume = Int(lines[2])
        else { return nil }
        self.init(
            position: position, duration: duration, volume: volume,
            isShuffling: lines[3] == "true", isRepeating: lines[4] == "true")
    }
}
