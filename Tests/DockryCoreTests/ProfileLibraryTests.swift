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

    func testChangingPinnedAppsKeepsWidgetsAndDividersInPlace() {
        var profile = Profile(name: "Work", items: [.app("a"), .widget(.clock), .app("b"), .divider, .runningApps])
        profile.pinnedApps = ["b", "a", "c"]
        XCTAssertEqual(profile.items, [.app("b"), .widget(.clock), .app("a"), .app("c"), .divider, .runningApps])
        profile.pinnedApps.removeAll { $0 == "b" }
        XCTAssertEqual(profile.items, [.widget(.clock), .app("a"), .app("c"), .divider, .runningApps])
        profile.widgets.append(.date)
        XCTAssertEqual(profile.items, [.widget(.clock), .widget(.date), .app("a"), .app("c"), .divider, .runningApps])
    }

    func testItemsStayUniqueAndKeepThePlaceForOpenApps() {
        var profile = Profile(name: "Work", items: [.app("a"), .app("a"), .widget(.clock), .widget(.clock), .divider, .divider])
        XCTAssertEqual(profile.items, [.app("a"), .runningApps, .widget(.clock), .divider, .divider])
        profile.insert(.app("a"), at: 3)
        XCTAssertEqual(profile.items, [.runningApps, .widget(.clock), .app("a"), .divider, .divider])
        profile.removeItem(at: 0)
        XCTAssertEqual(profile.items.first, .runningApps)
        profile.insert(.divider, at: 0)
        XCTAssertEqual(profile.items.first, .divider)
    }

    func testProfilesFromBeforeItemsGetTheOldLayout() throws {
        let json = #"{ "name": "Work", "pinnedApps": ["a"], "widgets": ["clock"] }"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.items, [.app("a"), .divider, .runningApps, .divider, .widget(.clock)])
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        XCTAssertEqual(saved["items"] as? [String], ["a", "divider", "running-apps", "divider", "widget:clock"])
        XCTAssertNil(saved["pinnedApps"])
    }

    func testUnknownWidgetsInItemsAreDropped() throws {
        let json = #"{ "name": "Work", "items": ["a", "widget:stocks", "widget:date"] }"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.items, [.app("a"), .runningApps, .widget(.date)])
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

    func testUpdatingAProfileReturnsItsNameAfterwards() {
        XCTAssertEqual(library.updateProfile(named: "Chill") { $0.name = " Home " }, "Home")
        XCTAssertEqual(library.updateProfile(named: "Home") { $0.name = "Work" }, "Home")
        XCTAssertEqual(library.updateProfile(named: "Work") { $0.desktop = 4 }, "Work")
        XCTAssertNil(library.updateProfile(named: "Gone") { $0.desktop = 4 })
    }

    func testMovingAProfileStaysInBounds() {
        library.moveProfile(named: "Work", by: 5)
        XCTAssertEqual(library.profiles.map(\.name), ["Chill", "Work"])
        library.moveProfile(named: "Work", by: -1)
        XCTAssertEqual(library.profiles.map(\.name), ["Work", "Chill"])
    }
}

final class ProfileCloneAndFieldsTests: XCTestCase {
    func testDuplicateCopiesTheProfileRightAfterItWithoutItsShortcut() {
        var work = Profile(name: "Work", pinnedApps: ["com.apple.Safari"], widgets: [.clock], desktop: 2)
        work.shortcut = KeyShortcut(keyCode: 18, modifierFlags: 0x900)
        work.wallpaper = "/tmp/work.jpg"
        var library = ProfileLibrary(profiles: [work, Profile(name: "Chill")])
        XCTAssertEqual(library.duplicateProfile(named: "Work"), "Work Copy")
        XCTAssertEqual(library.duplicateProfile(named: "Work"), "Work Copy 2")
        XCTAssertEqual(library.profiles.map(\.name), ["Work", "Work Copy 2", "Work Copy", "Chill"])
        let copy = library.profiles[2]
        XCTAssertEqual(copy.items, work.items)
        XCTAssertEqual(copy.desktop, 2)
        XCTAssertEqual(copy.wallpaper, "/tmp/work.jpg")
        XCTAssertNil(copy.shortcut)
        XCTAssertNil(library.duplicateProfile(named: "Nope"))
    }

    func testFoldersWallpaperAndOpeningAppsSurviveTheFile() throws {
        var profile = Profile(name: "Work", items: [.app("com.apple.Safari"), .folder("/Users/me/Downloads"), .runningApps])
        profile.wallpaper = "/Users/me/Pictures/work.heic"
        profile.opensAppsOnSwitch = true
        let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded, profile)
        XCTAssertEqual(decoded.folders, ["/Users/me/Downloads"])
    }

    func testFreshAppsIsChosenWhenAddingAndKeptByCopiesAndTheFile() throws {
        var library = ProfileLibrary(profiles: [Profile(name: "Work")])
        let name = library.addProfile(named: "Private", freshApps: true)
        let copy = library.duplicateProfile(named: name)!
        XCTAssertEqual(library.profiles.map(\.freshApps), [false, true, true])
        XCTAssertEqual(copy, "Private Copy")
        let decoded = try JSONDecoder().decode(ProfileLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(decoded.profiles.map(\.freshApps), [false, true, true])
    }

    func testBadOpensAppsValueIsIgnored() throws {
        let json = #"{"name": "Work", "opensAppsOnSwitch": "yes", "items": ["folder:/tmp"]}"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        XCTAssertFalse(profile.opensAppsOnSwitch)
        XCTAssertEqual(profile.folders, ["/tmp"])
    }
}
