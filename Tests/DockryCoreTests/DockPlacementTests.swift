import XCTest
@testable import DockryCore

final class DockPlacementTests: XCTestCase {
    // A built-in display with an external one to its right.
    private let builtIn = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let external = CGRect(x: 1512, y: -200, width: 2560, height: 1440)

    func testAtTheBottomEveryScreenGetsADock() {
        XCTAssertEqual(DockPlacement.screens([builtIn, external], position: .bottom), [0, 1])
    }

    func testOnTheLeftOnlyTheLeftmostScreenGetsADock() {
        XCTAssertEqual(DockPlacement.screens([builtIn, external], position: .left), [0])
        XCTAssertEqual(DockPlacement.screens([external, builtIn], position: .left), [1])
    }

    func testOnTheRightOnlyTheRightmostScreenGetsADock() {
        XCTAssertEqual(DockPlacement.screens([builtIn, external], position: .right), [1])
    }

    func testStackedScreensPreferTheMainScreen() {
        let above = CGRect(x: 0, y: 982, width: 1512, height: 982)
        XCTAssertEqual(DockPlacement.screens([builtIn, above], position: .left), [0])
        XCTAssertEqual(DockPlacement.screens([builtIn, above], position: .right), [0])
    }

    func testNoScreensNoDocks() {
        XCTAssertEqual(DockPlacement.screens([], position: .left), [])
    }
}
