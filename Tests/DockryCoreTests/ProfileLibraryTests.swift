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

    func testOpeningAppsOnSwitchIsPerProfileAndSaved() throws {
        var library = ProfileLibrary(profiles: [work, chill])
        library.activate(named: "Chill")
        library.setOpensAppsOnSwitch(true)
        let decoded = try JSONDecoder().decode(ProfileLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(decoded.profiles.map(\.opensAppsOnSwitch), [false, true])
    }

    func testDecodingAHandWrittenProfileFillsInDefaults() throws {
        let json = #"{ "profiles": [{ "name": "Gaming", "widgets": ["clock", "weather"], "desktop": 3 }] }"#
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
