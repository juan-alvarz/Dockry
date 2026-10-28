import XCTest
@testable import DockryCore

final class ClaudeUsageTests: XCTestCase {
    func testReadsBothWindows() throws {
        let json = """
            {"five_hour": {"utilization": 23.5, "resets_at": "2026-10-28T09:00:00.123+00:00"},
             "seven_day": {"utilization": 61, "resets_at": "2026-11-01T00:00:00Z"},
             "seven_day_opus": null}
            """
        let usage = try XCTUnwrap(ClaudeUsage(responseJSON: Data(json.utf8)))
        XCTAssertEqual(usage.session.percentUsed, 23.5)
        XCTAssertEqual(usage.week.percentUsed, 61)
        XCTAssertEqual(usage.week.resetsAt, ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z"))
        XCTAssertNotNil(usage.session.resetsAt)
    }

    func testResetTimesWithMicroseconds() throws {
        let json = #"{"five_hour": {"utilization": 1, "resets_at": "2026-10-28T09:00:00.943648+00:00"}, "seven_day": {"utilization": 1}}"#
        let usage = try XCTUnwrap(ClaudeUsage(responseJSON: Data(json.utf8)))
        XCTAssertEqual(usage.session.resetsAt, ISO8601DateFormatter().date(from: "2026-10-28T09:00:00Z"))
    }

    func testMissingResetTimeIsFine() throws {
        let json = #"{"five_hour": {"utilization": 0}, "seven_day": {"utilization": 5, "resets_at": null}}"#
        let usage = try XCTUnwrap(ClaudeUsage(responseJSON: Data(json.utf8)))
        XCTAssertNil(usage.session.resetsAt)
        XCTAssertEqual(usage.week.percentUsed, 5)
    }

    func testPercentStaysWithinZeroToHundred() throws {
        let json = #"{"five_hour": {"utilization": 130}, "seven_day": {"utilization": -2}}"#
        let usage = try XCTUnwrap(ClaudeUsage(responseJSON: Data(json.utf8)))
        XCTAssertEqual(usage.session.percentUsed, 100)
        XCTAssertEqual(usage.week.percentUsed, 0)
    }

    func testUnexpectedResponsesGiveNothing() {
        XCTAssertNil(ClaudeUsage(responseJSON: Data(#"{"error": {"type": "rate_limit_error"}}"#.utf8)))
        XCTAssertNil(ClaudeUsage(responseJSON: Data("not json".utf8)))
    }

    func testReadsTheAccessTokenFromClaudeCodesCredentials() {
        let credentials = #"{"claudeAiOauth": {"accessToken": "sk-ant-oat01-abc", "refreshToken": "x", "expiresAt": 1}}"#
        XCTAssertEqual(ClaudeUsage.accessToken(fromCredentials: Data(credentials.utf8)), "sk-ant-oat01-abc")
        XCTAssertNil(ClaudeUsage.accessToken(fromCredentials: Data("{}".utf8)))
    }

    func testAnExpiredSignInNeedsRefreshing() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func credentials(expiresAt: Double) -> Data {
            Data(#"{"claudeAiOauth": {"accessToken": "a", "expiresAt": \#(expiresAt)}}"#.utf8)
        }
        XCTAssertTrue(ClaudeUsage.needsRefresh(credentials(expiresAt: 999_000_000), now: now))
        XCTAssertTrue(ClaudeUsage.needsRefresh(credentials(expiresAt: 1_000_030_000), now: now))  // in 30 s
        XCTAssertFalse(ClaudeUsage.needsRefresh(credentials(expiresAt: 1_003_600_000), now: now))
        XCTAssertFalse(ClaudeUsage.needsRefresh(Data(#"{"claudeAiOauth": {"accessToken": "a"}}"#.utf8), now: now))
    }

    func testRefreshAsksForTheSavedScopes() throws {
        let credentials = #"{"claudeAiOauth": {"refreshToken": "r1", "scopes": ["user:inference", "user:profile"]}}"#
        let body = try XCTUnwrap(ClaudeUsage.refreshRequestBody(credentials: Data(credentials.utf8)))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object["grant_type"], "refresh_token")
        XCTAssertEqual(object["refresh_token"], "r1")
        XCTAssertEqual(object["scope"], "user:inference user:profile")
        XCTAssertEqual(object["client_id"], ClaudeUsage.clientID)
        XCTAssertNil(ClaudeUsage.refreshRequestBody(credentials: Data(#"{"claudeAiOauth": {}}"#.utf8)))
    }

    func testRefreshedCredentialsKeepEverythingElse() throws {
        let credentials = #"{"claudeAiOauth": {"accessToken": "old", "refreshToken": "r1", "expiresAt": 1, "subscriptionType": "max"}, "other": 1}"#
        let response = #"{"access_token": "new", "refresh_token": "r2", "expires_in": 3600, "token_type": "Bearer"}"#
        let now = Date(timeIntervalSince1970: 1_000_000)
        let updated = try XCTUnwrap(ClaudeUsage.credentials(Data(credentials.utf8), refreshedWith: Data(response.utf8), now: now))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        let oauth = try XCTUnwrap(object["claudeAiOauth"] as? [String: Any])
        XCTAssertEqual(oauth["accessToken"] as? String, "new")
        XCTAssertEqual(oauth["refreshToken"] as? String, "r2")
        XCTAssertEqual((oauth["expiresAt"] as? NSNumber)?.int64Value, 1_003_600_000)
        XCTAssertEqual(oauth["subscriptionType"] as? String, "max")
        XCTAssertEqual(object["other"] as? Int, 1)
        XCTAssertNil(ClaudeUsage.credentials(Data(credentials.utf8), refreshedWith: Data(#"{"error": "invalid_grant"}"#.utf8), now: now))
    }
}
