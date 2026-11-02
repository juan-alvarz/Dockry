import XCTest
@testable import DockryCore

/// Zen (pid 10) with a window in Projects (1) and one in Chill (2); Mail (pid 20) in Chill (3).
final class ProfileWindowRecordsTests: XCTestCase {
    private func twoProfiles() -> ProfileWindowRecords {
        var records = ProfileWindowRecords()
        records.see(1, pid: 10, newProfile: "Projects")
        records.see(2, pid: 10, newProfile: "Chill")
        records.see(3, pid: 20, newProfile: "Chill")
        return records
    }

    func testSwitchingToProjectsParksChillsWindowsAndKeepsProjectsOnes() {
        let plan = twoProfiles().switchPlan(to: "Projects", pids: [10, 20], separatesAll: true, freshProfiles: [])
        XCTAssertEqual(plan.park, [2, 3])
        XCTAssertEqual(plan.unpark, [])
    }

    func testSwitchingBackBringsTheParkedWindowsBackAndParksTheOthers() {
        var records = twoProfiles()
        records.parked(2, home: CGRect(x: 0, y: 0, width: 800, height: 600))
        records.parked(3, home: CGRect(x: 10, y: 10, width: 500, height: 400))
        let plan = records.switchPlan(to: "Chill", pids: [10, 20], separatesAll: true, freshProfiles: [])
        XCTAssertEqual(plan.park, [1])
        XCTAssertEqual(plan.unpark, [2, 3])
    }

    func testAParkedWindowIsNotParkedTwiceNorAnOnScreenOneBroughtBack() {
        var records = twoProfiles()
        records.parked(2, home: .zero)
        let plan = records.switchPlan(to: "Projects", pids: [10, 20], separatesAll: true, freshProfiles: [])
        XCTAssertEqual(plan.park, [3])
        XCTAssertEqual(plan.unpark, [])
    }

    func testWithTheSettingOffOnlyFreshProfilesWindowsMove() {
        var records = twoProfiles()
        records.see(4, pid: 30, newProfile: "Fresh")
        let plan = records.switchPlan(to: "Projects", pids: [10, 20, 30], separatesAll: false, freshProfiles: ["Fresh"])
        XCTAssertEqual(plan.park, [4])
        let intoFresh = records.switchPlan(to: "Fresh", pids: [10, 20, 30], separatesAll: false, freshProfiles: ["Fresh"])
        XCTAssertEqual(intoFresh.park, [1, 2, 3])
    }

    func testOnlyWindowsOfTheGivenAppsMove() {
        let plan = twoProfiles().switchPlan(to: "Projects", pids: [20], separatesAll: true, freshProfiles: [])
        XCTAssertEqual(plan.park, [3])
    }

    func testDockryRestartingKeepsEachWindowsProfile() throws {
        var records = twoProfiles()
        records.parked(2, home: CGRect(x: 1, y: 2, width: 3, height: 4))
        let data = try JSONEncoder().encode(records)
        var loaded = try JSONDecoder().decode(ProfileWindowRecords.self, from: data)
        XCTAssertEqual(loaded, records)
        // Seen again after the restart: same process, same profile.
        loaded.see(2, pid: 10, newProfile: "Projects")
        XCTAssertEqual(loaded.profile(ofWindow: 2), "Chill")
    }

    func testWhatOlderVersionsSavedStillLoads() throws {
        let json = #"{"8994": {"profile": "Projects", "pid": 10}, "51": {"profile": "Chill", "pid": 10, "home": [[0, 0], [800, 600]]}}"#
        let records = try JSONDecoder().decode(ProfileWindowRecords.self, from: Data(json.utf8))
        XCTAssertEqual(records.profile(ofWindow: 8994), "Projects")
        XCTAssertEqual(records.parkedWindows, [51])
    }

    func testANumberReusedByAnotherProcessIsANewWindow() {
        var records = twoProfiles()
        records.see(3, pid: 99, newProfile: "Projects")
        XCTAssertEqual(records.profile(ofWindow: 3), "Projects")
    }

    func testClosedWindowsAreForgotten() {
        var records = twoProfiles()
        records.keep(only: [1])
        XCTAssertEqual(records.profiles(ofPID: 10), ["Projects"])
        XCTAssertEqual(records.profiles(ofPID: 20), [])
    }

    func testRenamingAndRemovingProfilesKeepTheirWindows() {
        var records = twoProfiles()
        records.rename("Chill", to: "Home")
        XCTAssertEqual(records.profiles(ofPID: 10), ["Projects", "Home"])
        records.moveWindows(notIn: ["Projects"], to: "Projects")
        XCTAssertEqual(records.profiles(ofPID: 20), ["Projects"])
    }

    func testQuittingPutsBackEveryParkedWindow() {
        var records = twoProfiles()
        records.parked(2, home: .zero)
        records.parked(3, home: .zero)
        XCTAssertEqual(records.parkedWindows, [2, 3])
        records.unparked(2)
        XCTAssertEqual(records.parkedWindows, [3])
    }
}
