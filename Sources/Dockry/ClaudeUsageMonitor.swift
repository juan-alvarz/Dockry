import Foundation
import DockryCore
import Security

/// Fetches Claude plan usage every few minutes while the widget is showing, signed in with
/// the account Claude Code is signed in to. The endpoint is the unofficial one behind
/// Claude Code's `/usage`; it rate-limits hard, so this asks rarely and backs off on 429.
@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    enum State: Equatable {
        case loading
        /// No Claude Code sign-in in the Keychain (or access to it was denied).
        case signedOut
        /// The sign-in expired; opening Claude Code refreshes it.
        case expired
        case unavailable
        case usage(ClaudeUsage)
    }

    @Published private(set) var state = State.loading

    private static let refreshInterval: TimeInterval = 5 * 60
    /// For CI, which has no Claude account: point the widget at a local test server.
    private static let endpoint = URL(
        string: UserDefaults.standard.string(forKey: "claudeUsageEndpoint") ?? "https://api.anthropic.com/api/oauth/usage")!

    private var refreshTask: Task<Void, Never>?

    init() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let wait = await self?.refresh() ?? Self.refreshInterval
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Returns how long to wait before the next refresh.
    private func refresh() async -> TimeInterval {
        // Off the main thread: the first read waits for the user to answer the Keychain prompt.
        guard let token = await Task.detached(operation: Self.claudeCodeAccessToken).value else {
            state = .signedOut
            return Self.refreshInterval
        }
        var request = URLRequest(url: Self.endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else {
            // Offline: keep showing the last numbers.
            if case .loading = state { state = .unavailable }
            return Self.refreshInterval
        }
        switch status {
        case 200:
            state = ClaudeUsage(responseJSON: data).map(State.usage) ?? .unavailable
        case 401, 403:
            state = .expired
        case 429:
            // Rate limited; these limits are known to last half an hour or more.
            return 30 * 60
        default:
            if case .loading = state { state = .unavailable }
        }
        return Self.refreshInterval
    }

    /// Claude Code's saved sign-in. The first read makes macOS ask whether Dockry may use
    /// the "Claude Code-credentials" Keychain item.
    nonisolated private static func claudeCodeAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data
        else { return nil }
        return ClaudeUsage.accessToken(fromCredentials: data)
    }
}
