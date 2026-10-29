import Foundation
import XCTest
@testable import DockryCore

final class WindowFitTests: XCTestCase {
    // A 1000×800 screen with a 25-point menu bar and a 70-point dock at the bottom.
    let allowed = CGRect(x: 0, y: 70, width: 1000, height: 705)

    func testLeavesWindowsClearOfTheDockAlone() {
        let window = CGRect(x: 100, y: 200, width: 400, height: 300)
        XCTAssertEqual(WindowFit.frame(window, avoiding: .bottom, allowed: allowed), window)
    }

    func testMovesAWindowOutFromBehindTheDock() {
        let window = CGRect(x: 100, y: 20, width: 400, height: 300)
        XCTAssertEqual(WindowFit.frame(window, avoiding: .bottom, allowed: allowed), CGRect(x: 100, y: 70, width: 400, height: 300))
    }

    func testCutsAZoomedWindowToTheSpaceAboveTheDock() {
        let zoomed = CGRect(x: 0, y: 0, width: 1000, height: 775)
        XCTAssertEqual(WindowFit.frame(zoomed, avoiding: .bottom, allowed: allowed), allowed)
    }

    func testSideDocks() {
        let left = CGRect(x: 60, y: 0, width: 940, height: 775)
        XCTAssertEqual(WindowFit.frame(CGRect(x: 0, y: 100, width: 300, height: 300), avoiding: .left, allowed: left),
                       CGRect(x: 60, y: 100, width: 300, height: 300))
        let right = CGRect(x: 0, y: 0, width: 940, height: 775)
        XCTAssertEqual(WindowFit.frame(CGRect(x: 0, y: 0, width: 1000, height: 775), avoiding: .right, allowed: right), right)
        XCTAssertEqual(WindowFit.frame(CGRect(x: 800, y: 100, width: 300, height: 300), avoiding: .right, allowed: right),
                       CGRect(x: 640, y: 100, width: 300, height: 300))
    }

    func testTheAllowedAreaStopsAtTheDock() {
        let visible = CGRect(x: 0, y: 4, width: 1000, height: 771)  // a hidden macOS Dock keeps 4 points
        let dockArea = CGRect(x: 0, y: 0, width: 1000, height: 120)
        XCTAssertEqual(WindowFit.allowedArea(visible: visible, dockArea: dockArea, position: .bottom, thickness: 70), allowed)
        let right = WindowFit.allowedArea(visible: visible, dockArea: CGRect(x: 700, y: 0, width: 300, height: 800), position: .right, thickness: 60)
        XCTAssertEqual(right, CGRect(x: 0, y: 4, width: 940, height: 771))
    }
}
