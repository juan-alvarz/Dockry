import Foundation

/// How much of a Claude plan's usage limits are used, as `/usage` in Claude Code shows it.
public struct ClaudeUsage: Equatable {
    public struct Window: Equatable {
        /// 0–100.
        public let percentUsed: Double
        public let resetsAt: Date?

        public init(percentUsed: Double, resetsAt: Date?) {
            self.percentUsed = percentUsed
            self.resetsAt = resetsAt
        }
    }

    /// The rolling 5-hour limit.
    public let session: Window
    /// The weekly limit.
    public let week: Window

    public init(session: Window, week: Window) {
        self.session = session
        self.week = week
    }

    /// Reads the response of `api.anthropic.com/api/oauth/usage`, the endpoint behind
    /// Claude Code's `/usage`. It isn't documented, so this only relies on the two windows:
    /// `{"five_hour": {"utilization": 23.0, "resets_at": "…"}, "seven_day": {…}, …}`.
    public init?(responseJSON data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let session = Self.window(object["five_hour"]),
              let week = Self.window(object["seven_day"])
        else { return nil }
        self.init(session: session, week: week)
    }

    /// The access token in the credentials Claude Code keeps in the Keychain (the
    /// "Claude Code-credentials" item): `{"claudeAiOauth": {"accessToken": "…", …}}`.
    public static func accessToken(fromCredentials data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let oauth = object?["claudeAiOauth"] as? [String: Any]
        return oauth?["accessToken"] as? String
    }

    // Claude Code's own sign-in client, which its saved refresh token belongs to.
    public static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// Whether Claude Code's saved access token has expired (or is about to). Only Claude
    /// Code's command-line tool refreshes it, so it goes stale while the tool isn't used.
    public static func needsRefresh(_ credentials: Data, now: Date) -> Bool {
        guard let expiresAt = (oauth(credentials)?["expiresAt"] as? NSNumber)?.doubleValue else { return false }
        return Date(timeIntervalSince1970: expiresAt / 1000) < now.addingTimeInterval(60)
    }

    /// The request Claude Code itself makes to refresh its sign-in, or nil without a refresh token.
    public static func refreshRequestBody(credentials: Data) -> Data? {
        guard let oauth = oauth(credentials), let refreshToken = oauth["refreshToken"] as? String else { return nil }
        let scopes = (oauth["scopes"] as? [String]) ?? []
        let body: [String: Any] = [
            "grant_type": "refresh_token", "refresh_token": refreshToken,
            "client_id": clientID, "scope": scopes.joined(separator: " "),
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }

    /// `credentials` with the tokens from the refresh response, everything else kept as it was,
    /// so Claude Code reads it back like its own. Nil if the response isn't a token.
    public static func credentials(_ credentials: Data, refreshedWith response: Data, now: Date) -> Data? {
        guard var object = try? JSONSerialization.jsonObject(with: credentials) as? [String: Any],
              var oauth = object["claudeAiOauth"] as? [String: Any],
              let answer = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              let accessToken = answer["access_token"] as? String,
              let expiresIn = (answer["expires_in"] as? NSNumber)?.doubleValue
        else { return nil }
        oauth["accessToken"] = accessToken
        // Refresh tokens are single-use: the old one stops working once a new one is handed out.
        if let refreshToken = answer["refresh_token"] as? String { oauth["refreshToken"] = refreshToken }
        oauth["expiresAt"] = Int64((now.timeIntervalSince1970 + expiresIn) * 1000)
        object["claudeAiOauth"] = oauth
        return try? JSONSerialization.data(withJSONObject: object)
    }

    private static func oauth(_ credentials: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: credentials) as? [String: Any])?["claudeAiOauth"] as? [String: Any]
    }

    private static func window(_ value: Any?) -> Window? {
        guard let window = value as? [String: Any],
              let percent = (window["utilization"] as? NSNumber)?.doubleValue
        else { return nil }
        let resetsAt = (window["resets_at"] as? String).flatMap(parseDate)
        return Window(percentUsed: min(max(percent, 0), 100), resetsAt: resetsAt)
    }

    /// ISO 8601, with or without fractional seconds of any length (they're dropped; a reset
    /// time doesn't need them).
    private static func parseDate(_ text: String) -> Date? {
        let withoutFraction = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: withoutFraction)
    }
}
