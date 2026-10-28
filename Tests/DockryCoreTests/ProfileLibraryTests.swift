import XCTest
@testable import DockryCore

final class ProfileLibraryTests: XCTestCase {
    private let work = Profile(name: "Work", pinnedApps: ["com.apple.Safari"])
    private let chill = Profile(name: "Chill")

    func testFirstProfileIsActiveByDefault() {
        XCTAssertEqual(ProfileLibrary(profiles: [work, chill]).active, work)
    }

    func testUnknownActiveNameFallsBackToFirstProfile() {
        XCTAssertEqual(ProfileLibrary(profiles: [work, chill], activeProfileName: "Gone").active, work)
    }

    func testEmptyProfilesFallBackToDefaults() {
        XCTAssertEqual(ProfileLibrary(profiles: []).profiles, Profile.defaults)
    }

    func testDuplicateNamesKeepTheFirstProfile() {
        let library = ProfileLibrary(profiles: [work, Profile(name: "Work"), chill])
        XCTAssertEqual(library.profiles, [work, chill])
    }

    func testActivateIgnoresUnknownNames() {
        var library = ProfileLibrary(profiles: [work, chill])
        library.activate(named: "Chill")
        XCTAssertEqual(library.active, chill)
        library.activate(named: "Gone")
        XCTAssertEqual(library.active, chill)
    }

    func testPinAddsToTheActiveProfileOnce() {
        var library = ProfileLibrary(profiles: [work, chill])
        library.pin("com.apple.Notes")
        library.pin("com.apple.Notes")
        library.pin("com.apple.Safari")
        XCTAssertEqual(library.active.pinnedApps, ["com.apple.Safari", "com.apple.Notes"])
        XCTAssertEqual(library.profiles[1].pinnedApps, [])
    }

    func testUnpinRemovesFromTheActiveProfile() {
        var library = ProfileLibrary(profiles: [work, chill])
        library.unpin("com.apple.Safari")
        XCTAssertEqual(library.active.pinnedApps, [])
    }

    func testDecodingAHandWrittenProfileFillsInDefaults() throws {
        let json = #"{ "profiles": [{ "name": "Gaming", "widgets": ["clock", "stocks"], "desktop": 3 }] }"#
        let library = try JSONDecoder().decode(ProfileLibrary.self, from: Data(json.utf8))
        XCTAssertEqual(
            library.active,
            Profile(name: "Gaming", symbol: Profile.defaultSymbol, pinnedApps: [], widgets: [.clock], desktop: 3))
    }

    func testEncodingRoundTrips() throws {
        var library = ProfileLibrary()
        library.activate(named: "Chill")
        let decoded = try JSONDecoder().decode(ProfileLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(decoded, library)
    }
}

final class ProfileLibraryEditingTests: XCTestCase {
    private var library = ProfileLibrary(profiles: [Profile(name: "Work"), Profile(name: "Chill")])

    func testAddingAProfileGivesItAUniqueName() {
        XCTAssertEqual(library.addProfile(named: "Gaming"), "Gaming")
        XCTAssertEqual(library.addProfile(named: "Work"), "Work 2")
        XCTAssertEqual(library.profiles.map(\.name), ["Work", "Chill", "Gaming", "Work 2"])
    }

    func testRemovingTheActiveProfileActivatesTheFirst() {
        library.activate(named: "Chill")
        library.removeProfile(named: "Chill")
        XCTAssertEqual(library.active.name, "Work")
    }

    func testTheLastProfileCantBeRemoved() {
        library.removeProfile(named: "Chill")
        library.removeProfile(named: "Work")
        XCTAssertEqual(library.profiles.map(\.name), ["Work"])
    }

    func testRenamingTheActiveProfileKeepsItActive() {
        library.updateProfile(named: "Work") { $0.name = "Office" }
        XCTAssertEqual(library.active.name, "Office")
    }

    func testRenamesToTakenOrEmptyNamesAreIgnoredButOtherChangesApply() {
        library.updateProfile(named: "Work") {
            $0.name = "Chill"
            $0.desktop = 3
        }
        library.updateProfile(named: "Chill") { $0.name = "  " }
        XCTAssertEqual(library.profiles.map(\.name), ["Work", "Chill"])
        XCTAssertEqual(library.profiles[0].desktop, 3)
    }

    func testMovingAProfileStaysInBounds() {
        library.moveProfile(named: "Work", by: 5)
        XCTAssertEqual(library.profiles.map(\.name), ["Chill", "Work"])
        library.moveProfile(named: "Work", by: -1)
        XCTAssertEqual(library.profiles.map(\.name), ["Work", "Chill"])
    }
}
