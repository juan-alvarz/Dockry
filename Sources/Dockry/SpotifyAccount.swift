import AppKit
import CryptoKit
import DockryCore

/// The Spotify account used for searching, signed in through Spotify's website. Spotify
/// requires every app to have its own client ID, so the user registers a (free) app on
/// developer.spotify.com and pastes its client ID into Settings.
@MainActor
final class SpotifyAccount: ObservableObject {
    static let shared = SpotifyAccount()

    enum Status: Equatable {
        case signedOut
        case signingIn
        case signedIn
        case failed(String)
    }

    @Published var clientID: String {
        didSet { UserDefaults.standard.set(clientID.trimmingCharacters(in: .whitespaces), forKey: Self.clientIDKey) }
    }
    @Published private(set) var status: Status

    var canSearch: Bool { status == .signedIn || ScreenshotHook.spotifySearchResponse != nil }

    private static let clientIDKey = "spotifyClientID"
    // Whether a refresh token is in the keychain, so launching doesn't need to read it.
    private static let signedInKey = "spotifySignedIn"
    private static let refreshTokenAccount = "spotify-refresh-token"

    private var token: SpotifyToken?
    private var pendingSignIn: (verifier: String, state: String)?

    private init() {
        clientID = UserDefaults.standard.string(forKey: Self.clientIDKey) ?? ""
        status = UserDefaults.standard.bool(forKey: Self.signedInKey) ? .signedIn : .signedOut
    }

    /// Opens Spotify's sign-in page; it comes back through `handleCallback`.
    func signIn() {
        let clientID = clientID.trimmingCharacters(in: .whitespaces)
        guard !clientID.isEmpty else {
            status = .failed("Paste your app’s client ID first.")
            return
        }
        let verifier = Self.randomURLSafeString()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomURLSafeString()
        pendingSignIn = (verifier, state)
        status = .signingIn
        NSWorkspace.shared.open(SpotifyWebAPI.authorizeURL(clientID: clientID, codeChallenge: challenge, state: state))
    }

    func signOut() {
        token = nil
        status = .signedOut
        UserDefaults.standard.set(false, forKey: Self.signedInKey)
        Task { await Keychain.delete(Self.refreshTokenAccount) }
    }

    /// The dockry:// URL Spotify sends the browser back to after signing in.
    func handleCallback(_ url: URL) {
        guard let pending = pendingSignIn else { return }
        guard let code = SpotifyWebAPI.authorizationCode(fromCallback: url, state: pending.state) else {
            status = .failed("Spotify didn’t sign you in.")
            return
        }
        pendingSignIn = nil
        Task {
            do {
                let body = SpotifyWebAPI.tokenRequestBody(clientID: clientID, code: code, codeVerifier: pending.verifier)
                try await store(requestToken(body))
                status = .signedIn
                NSApp.activate(ignoringOtherApps: true)  // back from the browser to Settings
            } catch {
                status = .failed("Couldn’t finish signing in: \(error.localizedDescription)")
            }
        }
    }

    func search(_ query: String) async throws -> [SpotifySearchResult] {
        if let sample = ScreenshotHook.spotifySearchResponse {
            return try SpotifyWebAPI.parseSearch(Data(contentsOf: sample))
        }
        var request = URLRequest(url: SpotifyWebAPI.searchURL(query: query))
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        var (data, response) = try await URLSession.shared.data(for: request)
        // The token can be revoked or expire early; get a new one and try once more.
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            token = nil
            request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SpotifyError.requestFailed }
        return try SpotifyWebAPI.parseSearch(data)
    }

    private func accessToken() async throws -> String {
        if let token, token.expiresAt > Date() {
            return token.accessToken
        }
        guard let refreshToken = await Keychain.read(Self.refreshTokenAccount) else {
            status = .signedOut
            UserDefaults.standard.set(false, forKey: Self.signedInKey)
            throw SpotifyError.signedOut
        }
        do {
            try await store(requestToken(SpotifyWebAPI.refreshRequestBody(clientID: clientID, refreshToken: refreshToken)))
        } catch SpotifyError.requestFailed {
            // The refresh token no longer works (signed out on Spotify's side, app removed…).
            signOut()
            throw SpotifyError.signedOut
        }
        return token!.accessToken
    }

    private func requestToken(_ body: Data) async throws -> SpotifyToken {
        var request = URLRequest(url: SpotifyWebAPI.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SpotifyError.requestFailed }
        return try SpotifyWebAPI.parseToken(data, now: Date())
    }

    private func store(_ newToken: SpotifyToken) async {
        token = newToken
        // Spotify may hand out a new refresh token; the old one then stops working.
        if let refreshToken = newToken.refreshToken {
            await Keychain.save(refreshToken, for: Self.refreshTokenAccount)
            UserDefaults.standard.set(true, forKey: Self.signedInKey)
        }
    }

    private static func randomURLSafeString() -> String {
        base64URL(Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum SpotifyError: LocalizedError {
    case signedOut
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in to Spotify in Dockry’s settings to search."
        case .requestFailed: "Spotify didn’t answer. Try again in a moment."
        }
    }
}
