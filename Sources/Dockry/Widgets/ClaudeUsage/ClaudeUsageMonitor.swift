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
    /// When the numbers last came in.
    @Published private(set) var updatedAt: Date?

    /// claude.ai's own usage page, linked from the widget's popover.
    static let usagePage = URL(string: "https://claude.ai/settings/usage")!

    /// Whether a widget is in the dock, which is when usage is fetched.
    var isWatching: Bool { visibleWidgets > 0 }

    private static let refreshInterval: TimeInterval = 5 * 60
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    /// For CI, which has no Claude account: a file with a sample answer from the endpoint.
    private static let testResponse = UserDefaults.standard.string(forKey: "claudeUsageTestResponse")

    private var refreshTask: Task<Void, Never>?
    private var nextRefresh = Date.distantPast
    private var lastAttempt = Date.distantPast
    @Published private var visibleWidgets = 0
    /// Set when the user denies the Keychain prompt, so it isn't shown again until restart.
    private var keychainDenied = false

    private init() {}

    func widgetAppeared() {
        visibleWidgets += 1
        if refreshTask == nil { startRefreshing() }
    }

    private func startRefreshing() {
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

    /// Fetches now instead of at the next refresh, unless the last fetch was under a minute ago
    /// (the endpoint rate-limits hard).
    func refreshSoon() {
        guard refreshTask != nil, Date().timeIntervalSince(lastAttempt) > 60 else { return }
        nextRefresh = .distantPast
        // Wake the loop, which sleeps until the next refresh.
        refreshTask?.cancel()
        startRefreshing()
    }

    func widgetDisappeared() {
        visibleWidgets -= 1
        guard visibleWidgets == 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Returns how long to wait before the next refresh.
    private func refresh() async -> TimeInterval {
        lastAttempt = Date()
        if let testResponse = Self.testResponse {
            let data = FileManager.default.contents(atPath: testResponse) ?? Data()
            state = ClaudeUsage(responseJSON: data).map(State.usage) ?? .unavailable
            updatedAt = Date()
            return Self.refreshInterval
        }
        guard !keychainDenied else { return Self.refreshInterval }
        // On a background queue, never the main thread: the first read waits until the user
        // answers the Keychain prompt. (A Task.detached here still ran on the main thread.)
        let signIn = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { continuation.resume(returning: readClaudeCodeSignIn()) }
        }
        var credentials: Data
        switch signIn {
        case .credentials(let data, let account):
            credentials = data
            if ClaudeUsage.needsRefresh(data, now: Date()) {
                guard let refreshed = await refreshClaudeCodeSignIn(data, account: account) else {
                    state = .expired
                    return Self.refreshInterval
                }
                credentials = refreshed
            }
        case .missing:
            state = .signedOut
            return Self.refreshInterval
        case .denied:
            keychainDenied = true
            state = .accessDenied
            return Self.refreshInterval
        }
        guard let token = ClaudeUsage.accessToken(fromCredentials: credentials) else {
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
            updatedAt = Date()
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

/// Refreshes Claude Code's expired sign-in the way Claude Code does, and saves the new tokens
/// back into its keychain item: refresh tokens are single-use, so Claude Code needs the new
/// one too. Nil if that can't be done; Claude Code's sign-in is then left as it was.
private func refreshClaudeCodeSignIn(_ credentials: Data, account: String) async -> Data? {
    guard let body = ClaudeUsage.refreshRequestBody(credentials: credentials) else { return nil }
    // First make sure the item can be written, so a refresh never uses up the refresh token
    // without Claude Code getting the new one.
    guard await onBackground({ writeClaudeCodeSignIn(credentials, account: account) }) else { return nil }
    var request = URLRequest(url: ClaudeUsage.tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    guard let (data, response) = try? await URLSession.shared.data(for: request),
          (response as? HTTPURLResponse)?.statusCode == 200,
          let refreshed = ClaudeUsage.credentials(credentials, refreshedWith: data, now: Date())
    else { return nil }
    if !(await onBackground({ writeClaudeCodeSignIn(refreshed, account: account) })) {
        NSLog("Dockry: refreshed Claude Code's sign-in but couldn't save it; Claude Code will ask to sign in again")
    }
    return refreshed
}

private func onBackground<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .utility).async { continuation.resume(returning: work()) }
    }
}

private enum ClaudeCodeSignIn {
    case credentials(Data, account: String)
    case missing
    case denied
}

private let claudeCodeService = "Claude Code-credentials"

/// Claude Code's saved sign-in. The first read makes macOS ask whether Dockry may use the
/// "Claude Code-credentials" Keychain item, and blocks until the user answers.
private func readClaudeCodeSignIn() -> ClaudeCodeSignIn {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: claudeCodeService,
        kSecReturnData as String: true,
        kSecReturnAttributes as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    switch SecItemCopyMatching(query as CFDictionary, &result) {
    case errSecSuccess:
        guard let item = result as? [String: Any], let data = item[kSecValueData as String] as? Data else { return .missing }
        return .credentials(data, account: item[kSecAttrAccount as String] as? String ?? "")
    case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
        return .denied
    default:
        return .missing
    }
}

private func writeClaudeCodeSignIn(_ credentials: Data, account: String) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: claudeCodeService,
        kSecAttrAccount as String: account,
    ]
    let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: credentials] as CFDictionary)
    if status != errSecSuccess {
        NSLog("Dockry: couldn't update Claude Code's sign-in: \(status)")
    }
    return status == errSecSuccess
}
