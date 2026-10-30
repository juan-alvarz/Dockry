import XCTest
@testable import DockryCore

final class DockMagnificationTests: XCTestCase {
    private let icons = Array(repeating: DockMagnification.Item(length: 48, magnifies: true), count: 5)

    private func place(_ items: [DockMagnification.Item], pointer: Double?) -> DockMagnification.Placement {
        DockMagnification.place(items, spacing: 6, pointer: pointer, magnification: 2, reach: 150)
    }

    func testWithoutAPointerItemsKeepTheirNormalLayout() {
        let placement = place(icons, pointer: nil)
        XCTAssertEqual(placement.starts, [0, 54, 108, 162, 216])
        XCTAssertEqual(placement.scales, [1, 1, 1, 1, 1])
    }

    func testTheIconUnderThePointerGrowsTheMostAndNeighboursLess() {
        let placement = place(icons, pointer: 108 + 24)  // the middle of the third icon
        XCTAssertEqual(placement.scales[2], 2, accuracy: 0.001)
        XCTAssertEqual(placement.scales[1], placement.scales[3], accuracy: 0.001)
        XCTAssertGreaterThan(placement.scales[1], placement.scales[0])
        XCTAssertGreaterThan(placement.scales[0], 1)
    }

    func testTheSpotUnderThePointerStaysPut() {
        let pointer = 162 + 10.0  // into the fourth icon
        let placement = place(icons, pointer: pointer)
        let fraction = 10.0 / 48
        let fourthStart = placement.starts[3], fourthLength = 48 * placement.scales[3]
        XCTAssertEqual(fourthStart + fraction * fourthLength, pointer, accuracy: 0.001)
    }

    func testAWideItemGrowsFullyAnywhereAlongIt() {
        let widget = DockMagnification.Item(length: 200, magnifies: true, plateau: 76)
        let items = [widget] + icons
        // Anywhere but its outer half-icon at each end is as close as an icon's center.
        XCTAssertEqual(place(items, pointer: 170).scales[0], 2, accuracy: 0.001)
        XCTAssertEqual(place(items, pointer: 100).scales[0], 2, accuracy: 0.001)
        XCTAssertGreaterThan(place(items, pointer: 190).scales[0], 1.9)
        // Without a plateau, the same spot near its end is far from its center.
        let plain = [DockMagnification.Item(length: 200, magnifies: true)] + icons
        XCTAssertLessThan(place(plain, pointer: 190).scales[0], 1.5)
    }

    func testItemsThatDontMagnifyKeepTheirSize() {
        let items = [DockMagnification.Item(length: 200, magnifies: false)] + icons
        XCTAssertEqual(place(items, pointer: 100).scales[0], 1)
    }

    func testItemsBeyondTheReachDontGrow() {
        let placement = place(icons, pointer: 0)
        XCTAssertEqual(placement.scales[4], 1)
    }

    func testItemsDontOverlap() {
        let placement = place(icons, pointer: 140)
        for index in 1..<icons.count {
            let previousEnd = placement.starts[index - 1] + 48 * placement.scales[index - 1]
            XCTAssertEqual(placement.starts[index] - previousEnd, 6, accuracy: 0.001)
        }
    }
}
