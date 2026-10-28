import Foundation
import DockryCore
import Security

/// Fetches Claude plan usage every few minutes while a Claude widget is showing, signed in
/// with the account Claude Code is signed in to. The endpoint is the unofficial one behind
/// Claude Code's `/usage`; it rate-limits hard, so this asks rarely, backs off on 429, and
/// is shared, so switching profiles doesn't start new requests or lose the last numbers.
@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    static let shared = ClaudeUsageMonitor()

    enum State: Equatable {
        case loading
        /// No Claude Code sign-in in the Keychain.
        case signedOut
        /// The user said no to the Keychain prompt; Dockry doesn't ask again until it restarts.
        case accessDenied
        /// The sign-in expired; opening Claude Code refreshes it.
        case expired
        case unavailable
        case usage(ClaudeUsage)
    }

    @Published private(set) var state = State.loading

    private static let refreshInterval: TimeInterval = 5 * 60
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    /// For CI, which has no Claude account: a file with a sample answer from the endpoint.
    private static let testResponse = UserDefaults.standard.string(forKey: "claudeUsageTestResponse")

    private var refreshTask: Task<Void, Never>?
    private var nextRefresh = Date.distantPast
    private var visibleWidgets = 0

    private init() {}

    func widgetAppeared() {
        visibleWidgets += 1
        guard refreshTask == nil else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                let wait = nextRefresh.timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                } else {
                    nextRefresh = Date().addingTimeInterval(await refresh())
                }
            }
        }
    }

    func widgetDisappeared() {
        visibleWidgets -= 1
        guard visibleWidgets == 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Returns how long to wait before the next refresh.
    private func refresh() async -> TimeInterval {
        if let testResponse = Self.testResponse {
            let data = FileManager.default.contents(atPath: testResponse) ?? Data()
            state = ClaudeUsage(responseJSON: data).map(State.usage) ?? .unavailable
            return Self.refreshInterval
        }
        // On a background queue, never the main thread: the first read waits until the user
        // answers the Keychain prompt. (A Task.detached here still ran on the main thread.)
        let signIn = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { continuation.resume(returning: readClaudeCodeSignIn()) }
        }
        let token: String
        switch signIn {
        case .token(let value):
            token = value
        case .missing:
            state = .signedOut
            return Self.refreshInterval
        case .denied:
            state = .accessDenied
            return .infinity
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
        case 401:
            state = .expired
        default:
            // 429 (rate limited) or anything unexpected: keep the last numbers if there are any.
            if case .loading = state { state = .unavailable }
            // Rate limits are known to last half an hour or more.
            if status == 429 { return 30 * 60 }
        }
        return Self.refreshInterval
    }
}

private enum ClaudeCodeSignIn {
    case token(String)
    case missing
    case denied
}

/// Claude Code's saved sign-in. The first read makes macOS ask whether Dockry may use the
/// "Claude Code-credentials" Keychain item, and blocks until the user answers.
private func readClaudeCodeSignIn() -> ClaudeCodeSignIn {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "Claude Code-credentials",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    switch SecItemCopyMatching(query as CFDictionary, &result) {
    case errSecSuccess:
        let token = (result as? Data).flatMap(ClaudeUsage.accessToken(fromCredentials:))
        return token.map(ClaudeCodeSignIn.token) ?? .missing
    case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
        return .denied
    default:
        return .missing
    }
}
