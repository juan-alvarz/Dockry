import XCTest
@testable import DockryCore

final class SpotifyWebAPITests: XCTestCase {
    func testTheAuthorizeURLAsksForAPKCECode() throws {
        let url = SpotifyWebAPI.authorizeURL(clientID: "abc", codeChallenge: "xyz", state: "s1")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["client_id"], "abc")
        XCTAssertEqual(query["code_challenge"], "xyz")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertEqual(query["redirect_uri"], "dockry://spotify-callback")
        XCTAssertEqual(query["state"], "s1")
    }

    func testTheCallbackCodeNeedsTheMatchingState() throws {
        let url = try XCTUnwrap(URL(string: "dockry://spotify-callback?code=C0DE&state=s1"))
        XCTAssertEqual(SpotifyWebAPI.authorizationCode(fromCallback: url, state: "s1"), "C0DE")
        XCTAssertNil(SpotifyWebAPI.authorizationCode(fromCallback: url, state: "other"))
        let denied = try XCTUnwrap(URL(string: "dockry://spotify-callback?error=access_denied&state=s1"))
        XCTAssertNil(SpotifyWebAPI.authorizationCode(fromCallback: denied, state: "s1"))
    }

    func testTokenRequestsAreFormEncoded() {
        let body = String(decoding: SpotifyWebAPI.refreshRequestBody(clientID: "abc", refreshToken: "r/t+1"), as: UTF8.self)
        XCTAssertEqual(body, "grant_type=refresh_token&refresh_token=r%2Ft%2B1&client_id=abc")
    }

    func testParsesATokenAndExpiresItEarly() throws {
        let json = #"{"access_token":"A","token_type":"Bearer","expires_in":3600,"refresh_token":"R"}"#
        let now = Date(timeIntervalSince1970: 0)
        let token = try SpotifyWebAPI.parseToken(Data(json.utf8), now: now)
        XCTAssertEqual(token, SpotifyToken(accessToken: "A", refreshToken: "R", expiresAt: Date(timeIntervalSince1970: 3540)))
    }

    func testParsesSearchResults() throws {
        let json = """
            {"tracks": {"items": [{
              "uri": "spotify:track:1", "name": "Between the Bars",
              "artists": [{"name": "Elliott Smith"}, {"name": "Guest"}],
              "album": {"name": "Either/Or", "images": [
                {"url": "https://i.scdn.co/640", "width": 640},
                {"url": "https://i.scdn.co/64", "width": 64}]}
            }]}}
            """
        XCTAssertEqual(try SpotifyWebAPI.parseSearch(Data(json.utf8)), [SpotifySearchResult(
            uri: "spotify:track:1", title: "Between the Bars", artist: "Elliott Smith, Guest",
            album: "Either/Or", artworkURL: URL(string: "https://i.scdn.co/64"))])
    }

    func testReadsThePlaybackAppleScriptOutput() {
        XCTAssertEqual(
            SpotifyPlayback(appleScriptOutput: "83\n141\n70\ntrue\nfalse\n"),
            SpotifyPlayback(position: 83, duration: 141, volume: 70, isShuffling: true, isRepeating: false))
        XCTAssertNil(SpotifyPlayback(appleScriptOutput: ""))
    }
}
