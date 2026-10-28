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
}
