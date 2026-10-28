import XCTest
@testable import DockryCore

final class ClipboardHistoryTests: XCTestCase {
    func testNewestFirst() {
        var history = ClipboardHistory()
        history.add("first")
        history.add("second")
        XCTAssertEqual(history.items, ["second", "first"])
    }

    func testCopyingAgainMovesToTheTop() {
        var history = ClipboardHistory()
        history.add("a")
        history.add("b")
        history.add("a")
        XCTAssertEqual(history.items, ["a", "b"])
    }

    func testKeepsOnlyTheNewestUpToTheLimit() {
        var history = ClipboardHistory(limit: 2)
        ["a", "b", "c"].forEach { history.add($0) }
        XCTAssertEqual(history.items, ["c", "b"])
    }

    func testIgnoresWhitespaceOnlyText() {
        var history = ClipboardHistory()
        history.add("  \n\t")
        history.add("")
        XCTAssertEqual(history.items, [])
    }

    func testPreviewIsOneLine() {
        XCTAssertEqual(ClipboardHistory.preview(of: "  let x = 1\n\n    print(x)  "), "let x = 1 print(x)")
    }
}
