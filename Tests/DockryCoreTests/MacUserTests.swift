import XCTest
@testable import DockryCore

final class MacUserTests: XCTestCase {
    private func listing(_ records: [[String: [String]]]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: records, format: .xml, options: 0)
    }

    private func record(_ name: String, uid: String, realName: String? = nil, extra: [String: [String]] = [:]) -> [String: [String]] {
        var record = ["dsAttrTypeStandard:RecordName": [name], "dsAttrTypeStandard:UniqueID": [uid]]
        record["dsAttrTypeStandard:RealName"] = realName.map { [$0] }
        return record.merging(extra) { $1 }
    }

    func testKeepsPeopleAndDropsSystemAccounts() throws {
        let users = MacUser.parseDirectoryListing(try listing([
            record("_analyticsd", uid: "263", realName: "Analytics Daemon"),
            record("daemon", uid: "1"),
            record("nobody", uid: "-2"),
            record("guest", uid: "201"),
            record("juan", uid: "501", realName: "Juan Alvarez",
                   extra: ["dsAttrTypeStandard:Picture": ["/Library/User Pictures/Animals/Eagle.heic"]]),
            record("helper", uid: "502", extra: ["dsAttrTypeStandard:IsHidden": ["1"]]),
            record("alex", uid: "503", realName: "Alex Rivera"),
        ]))
        XCTAssertEqual(users, [
            MacUser(name: "alex", fullName: "Alex Rivera", uid: 503),
            MacUser(name: "juan", fullName: "Juan Alvarez", uid: 501, picturePath: "/Library/User Pictures/Animals/Eagle.heic"),
        ])
    }

    func testFullNameFallsBackToTheShortName() throws {
        let users = MacUser.parseDirectoryListing(try listing([record("sam", uid: "504")]))
        XCTAssertEqual(users.first?.fullName, "sam")
    }

    func testUnreadableOutputGivesNoUsers() {
        XCTAssertEqual(MacUser.parseDirectoryListing(Data("not a plist".utf8)), [])
    }

    func testInitials() {
        XCTAssertEqual(MacUser(name: "a", fullName: "Alex Rivera", uid: 501).initials, "AR")
        XCTAssertEqual(MacUser(name: "a", fullName: "alex", uid: 501).initials, "A")
        XCTAssertEqual(MacUser(name: "a", fullName: "Ana María López", uid: 501).initials, "AM")
    }
}
