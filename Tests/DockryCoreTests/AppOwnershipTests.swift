import XCTest
@testable import DockryCore

final class AppOwnershipTests: XCTestCase {
    private let launched = Date(timeIntervalSince1970: 1_800_000_000.25)

    func testTheSameProcessKeepsItsProfile() {
        let saved = AppOwnership(entries: [.init(pid: 42, launchedAt: launched, profile: "Chill")])
        XCTAssertEqual(saved.profile(forPID: 42, launchedAt: launched.addingTimeInterval(0.4)), "Chill")
    }

    func testAReusedProcessIDGetsNoProfile() {
        let saved = AppOwnership(entries: [.init(pid: 42, launchedAt: launched, profile: "Chill")])
        XCTAssertNil(saved.profile(forPID: 42, launchedAt: launched.addingTimeInterval(3600)))
        XCTAssertNil(saved.profile(forPID: 43, launchedAt: launched))
    }

    func testAMissingLaunchTimeOnlyMatchesAnotherMissingOne() {
        let saved = AppOwnership(entries: [
            .init(pid: 42, launchedAt: nil, profile: "Work"),
            .init(pid: 7, launchedAt: launched, profile: "Chill"),
        ])
        XCTAssertEqual(saved.profile(forPID: 42, launchedAt: nil), "Work")
        XCTAssertNil(saved.profile(forPID: 42, launchedAt: launched))
        XCTAssertNil(saved.profile(forPID: 7, launchedAt: nil))
    }

    func testRoundTripsThroughJSON() throws {
        let saved = AppOwnership(entries: [.init(pid: 42, launchedAt: launched, profile: "Chill")])
        let decoded = try JSONDecoder().decode(AppOwnership.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded.profile(forPID: 42, launchedAt: launched), "Chill")
    }
}
