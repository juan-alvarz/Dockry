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

    func testDropIndexRoundsToTheNearestSlotAndStaysInRange() {
        XCTAssertEqual(DockLayout.dropIndex(from: 1, slotsMoved: 0.4, count: 5), 1)
        XCTAssertEqual(DockLayout.dropIndex(from: 1, slotsMoved: 1.6, count: 5), 3)
        XCTAssertEqual(DockLayout.dropIndex(from: 1, slotsMoved: -0.6, count: 5), 0)
        XCTAssertEqual(DockLayout.dropIndex(from: 3, slotsMoved: 9, count: 5), 4)
        XCTAssertEqual(DockLayout.dropIndex(from: 3, slotsMoved: -9, count: 5), 0)
    }

    func testEachAppAppearsOnce() {
        let sections = DockLayout.sections(pinned: ["safari", "safari"], running: ["notes", "notes"])
        XCTAssertEqual(sections.pinned.map(\.bundleID), ["safari"])
        XCTAssertEqual(sections.running.map(\.bundleID), ["notes"])
    }
}
