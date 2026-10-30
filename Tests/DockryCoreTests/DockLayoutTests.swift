import XCTest
@testable import DockryCore

final class DockLayoutTests: XCTestCase {
    private func ids(_ elements: [DockElement]) -> [String] { elements.map(\.id) }

    func testPinnedAppsKeepProfileOrderAndShowWhetherTheyRun() {
        let elements = DockLayout.elements(items: [.app("mail"), .app("safari"), .runningApps], running: ["safari"])
        XCTAssertEqual(elements.map(\.content), [
            .app(DockEntry(bundleID: "mail", isPinned: true, isRunning: false)),
            .app(DockEntry(bundleID: "safari", isPinned: true, isRunning: true)),
        ])
    }

    func testRunningAppsThatArentPinnedGoInTheirPlaceInLaunchOrder() {
        let items: [DockItem] = [.app("safari"), .divider, .widget(.clock), .divider, .runningApps]
        let elements = DockLayout.elements(items: items, running: ["notes", "safari", "calculator", "notes"])
        XCTAssertEqual(ids(elements), ["safari", "divider:1", "widget:clock", "divider:3", "notes", "calculator"])
        XCTAssertEqual(elements[4].itemIndex, 4)
        XCTAssertEqual(ids(DockLayout.elements(items: items, running: ["notes"], showsUnpinned: false)), ["safari", "divider:1", "widget:clock"])
    }

    func testDividersShowWhereTheyWerePut() {
        // At the start, side by side, and at the end: all where the user put them.
        let items: [DockItem] = [.divider, .app("a"), .divider, .divider, .app("b"), .divider]
        XCTAssertEqual(ids(DockLayout.elements(items: items, running: [])), ["divider:0", "a", "divider:2", "divider:3", "b", "divider:5"])
    }

    func testDividersCutOffOnlyByHiddenItemsAreLeftOut() {
        // An empty open-apps group between two dividers, a missing app before the first, and
        // nothing shown after the last.
        let items: [DockItem] = [.app("missing"), .divider, .app("a"), .divider, .runningApps, .divider, .app("b"), .divider, .runningApps]
        let shown = DockLayout.elements(items: items, running: [], isShown: { $0 != "missing" })
        XCTAssertEqual(ids(shown), ["a", "divider:3", "b"])
        // The Default profile with no other apps open: no stray divider after Finder.
        XCTAssertEqual(ids(DockLayout.elements(items: [.app("finder"), .divider, .runningApps], running: [])), ["finder"])
    }

    func testDropIndexGoesPastAnElementOnceTheCenterCrossesIt() {
        // Apps 10 long, a widget 40 long, spacing 2: centers 5, 32, 59.
        let lengths = [10.0, 40, 10]
        XCTAssertEqual(DockLayout.dropIndex(from: 0, distance: 20, lengths: lengths, spacing: 2), 0)
        XCTAssertEqual(DockLayout.dropIndex(from: 0, distance: 28, lengths: lengths, spacing: 2), 1)
        XCTAssertEqual(DockLayout.dropIndex(from: 0, distance: 100, lengths: lengths, spacing: 2), 2)
        XCTAssertEqual(DockLayout.dropIndex(from: 2, distance: -60, lengths: lengths, spacing: 2), 0)
        // Two icons over, exactly.
        XCTAssertEqual(DockLayout.dropIndex(from: 0, distance: 108, lengths: [48, 48, 48, 48], spacing: 6), 2)
        XCTAssertEqual(DockLayout.dropIndex(from: 3, distance: -108, lengths: [48, 48, 48, 48], spacing: 6), 1)
    }

    func testShiftIsTheLengthOfWhatItMovedPast() {
        let lengths = [10.0, 40, 10]
        XCTAssertEqual(DockLayout.shift(from: 0, to: 1, lengths: lengths, spacing: 2), 42)
        XCTAssertEqual(DockLayout.shift(from: 2, to: 0, lengths: lengths, spacing: 2), -54)
    }

    func testMovingAWidgetBetweenApps() {
        let items: [DockItem] = [.app("spotify"), .app("zen"), .runningApps, .divider, .widget(.date)]
        let elements = DockLayout.elements(items: items, running: [])
        // spotify, zen, divider, date: move date to between spotify and zen.
        let moved = DockLayout.items(items, afterMoving: 3, to: 1, in: elements)
        XCTAssertEqual(moved, [.app("spotify"), .widget(.date), .app("zen"), .runningApps, .divider])
    }

    func testMovingForwardLandsAfterTheElementItPassed() {
        let items: [DockItem] = [.divider, .app("a"), .app("b"), .runningApps, .widget(.clock)]
        let elements = DockLayout.elements(items: items, running: [])
        // The leading divider shows too, so "a" is element 1 and the clock element 3.
        XCTAssertEqual(DockLayout.items(items, afterMoving: 1, to: 3, in: elements), [.divider, .app("b"), .runningApps, .widget(.clock), .app("a")])
    }

    func testDraggingAnOpenAppPinsIt() {
        let items: [DockItem] = [.app("a"), .divider, .runningApps]
        let elements = DockLayout.elements(items: items, running: ["notes"])
        XCTAssertEqual(ids(elements), ["a", "divider:1", "notes"])
        XCTAssertEqual(DockLayout.items(items, afterMoving: 2, to: 0, in: elements), [.app("notes"), .app("a"), .divider, .runningApps])
        XCTAssertEqual(DockLayout.items(items, afterMoving: 2, to: 2, in: elements), items)
    }
}

final class DockLayoutFolderTests: XCTestCase {
    func testFoldersShowInTheirPlace() {
        let elements = DockLayout.elements(items: [.app("a"), .folder("/f"), .runningApps], running: ["b"])
        XCTAssertEqual(elements.map(\.id), ["a", "folder:/f", "b"])
    }
}

final class DockLayoutDropTests: XCTestCase {
    private let elements = DockLayout.elements(items: [.app("a"), .divider, .widget(.clock)], running: [])

    func testDropGoesInFrontOfTheFirstElementPastIt() {
        XCTAssertEqual(DockLayout.dropGap(at: 5, centers: [10, 30, 50]), 0)
        XCTAssertEqual(DockLayout.dropGap(at: 35, centers: [10, 30, 50]), 2)
        XCTAssertEqual(DockLayout.dropGap(at: 99, centers: [10, 30, 50]), 3)
    }

    func testGapBecomesAnItemIndex() {
        XCTAssertEqual(DockLayout.itemIndex(insertingAt: 0, elements: elements, itemCount: 3), 0)
        XCTAssertEqual(DockLayout.itemIndex(insertingAt: 2, elements: elements, itemCount: 3), 2)
        XCTAssertEqual(DockLayout.itemIndex(insertingAt: 3, elements: elements, itemCount: 3), 3)
        XCTAssertEqual(DockLayout.itemIndex(insertingAt: 0, elements: [], itemCount: 2), 2)
    }
}
