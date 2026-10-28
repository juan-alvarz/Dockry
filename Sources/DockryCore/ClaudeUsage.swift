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
