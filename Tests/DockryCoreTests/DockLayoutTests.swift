import XCTest
@testable import DockryCore

final class DockLayoutTests: XCTestCase {
    func testPinnedAppsKeepProfileOrderAndShowWhetherTheyRun() {
        let sections = DockLayout.sections(pinned: ["mail", "safari"], running: ["safari"])
        XCTAssertEqual(sections.pinned, [
            DockEntry(bundleID: "mail", isPinned: true, isRunning: false),
            DockEntry(bundleID: "safari", isPinned: true, isRunning: true),
        ])
        XCTAssertEqual(sections.running, [])
    }

    func testRunningAppsThatArentPinnedFollowInLaunchOrder() {
        let sections = DockLayout.sections(pinned: ["safari"], running: ["notes", "safari", "calculator"])
        XCTAssertEqual(sections.running.map(\.bundleID), ["notes", "calculator"])
        XCTAssertTrue(sections.running.allSatisfy { $0.isRunning && !$0.isPinned })
    }

    func testEachAppAppearsOnce() {
        let sections = DockLayout.sections(pinned: ["safari", "safari"], running: ["notes", "notes"])
        XCTAssertEqual(sections.pinned.map(\.bundleID), ["safari"])
        XCTAssertEqual(sections.running.map(\.bundleID), ["notes"])
    }
}
