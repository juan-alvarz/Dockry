import XCTest
@testable import DockryCore

final class WidgetInfoTests: XCTestCase {
    func testTheCatalogHasEveryWidgetOnce() {
        XCTAssertEqual(Set(WidgetCatalog.all.map(\.kind)), Set(WidgetKind.allCases))
        XCTAssertEqual(WidgetCatalog.all.count, WidgetKind.allCases.count)
    }

    func testEveryWidgetDescribesItself() {
        for info in WidgetCatalog.all {
            XCTAssertEqual(info.kind.info, info)
            XCTAssertFalse(info.name.isEmpty, "\(info.kind)")
            XCTAssertFalse(info.summary.isEmpty, "\(info.kind)")
            XCTAssertFalse(info.details.isEmpty, "\(info.kind)")
            XCTAssertFalse(info.symbol.isEmpty, "\(info.kind)")
            XCTAssertEqual(HexColor.normalized(info.tint), info.tint, "\(info.kind)'s tint")
        }
    }

    func testNamesAreUnique() {
        let names = WidgetCatalog.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }
}
