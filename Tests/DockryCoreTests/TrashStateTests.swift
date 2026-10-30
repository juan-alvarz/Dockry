import XCTest
@testable import DockryCore

final class TrashStateTests: XCTestCase {
    func testFinderBookkeepingDoesntMakeItFull() {
        XCTAssertFalse(TrashState.isFull(entryCount: 0, hasDSStore: false))
        XCTAssertFalse(TrashState.isFull(entryCount: 1, hasDSStore: true))
        XCTAssertTrue(TrashState.isFull(entryCount: 1, hasDSStore: false))
        XCTAssertTrue(TrashState.isFull(entryCount: 2, hasDSStore: true))
    }

    func testTrashIsAWidget() throws {
        XCTAssertEqual(try JSONDecoder().decode(Profile.self, from: Data(#"{"name": "A", "items": ["widget:trash"]}"#.utf8)).widgets, [.trash])
    }
}
