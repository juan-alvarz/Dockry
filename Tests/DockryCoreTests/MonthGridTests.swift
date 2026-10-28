import XCTest
@testable import DockryCore

final class MonthGridTests: XCTestCase {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string + "T12:00:00Z")!
    }

    func testOctober2026StartsOnAThursday() {
        let calendar = calendar(firstWeekday: 1)  // Sunday
        let weeks = MonthGrid.weeks(containing: date("2026-10-28"), calendar: calendar)
        XCTAssertEqual(weeks.count, 5)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(weeks[0].prefix(4).compactMap { $0 }.count, 0)
        XCTAssertEqual(weeks[0][4].map { calendar.component(.day, from: $0) }, 1)
        XCTAssertEqual(weeks.joined().compactMap { $0 }.count, 31)
    }

    func testWeeksCanStartOnMonday() {
        let weeks = MonthGrid.weeks(containing: date("2026-10-01"), calendar: calendar(firstWeekday: 2))
        XCTAssertEqual(weeks[0].prefix(3).compactMap { $0 }.count, 0)
        XCTAssertNotNil(weeks[0][3])
    }
}
