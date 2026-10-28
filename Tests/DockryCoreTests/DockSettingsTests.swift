import XCTest
@testable import DockryCore

final class DockSettingsTests: XCTestCase {
    func testReadsTheMacDockPreferences() {
        let settings = DockSettings(macDockPreferences: [
            "orientation": "left", "tilesize": 36, "magnification": true, "largesize": 96.5,
            "autohide": NSNumber(value: true), "show-process-indicators": false, "launchanim": 0,
        ])
        XCTAssertEqual(settings, DockSettings(
            position: .left, iconSize: 36, magnifies: true, magnifiedSize: 96.5,
            autohides: true, showsIndicators: false, animatesLaunch: false))
    }

    func testMissingMacDockPreferencesGetTheDocksDefaults() {
        let settings = DockSettings(macDockPreferences: [:])
        XCTAssertEqual(settings.position, .bottom)
        XCTAssertFalse(settings.magnifies)
        XCTAssertFalse(settings.autohides)
        XCTAssertTrue(settings.showsIndicators)
        XCTAssertTrue(settings.animatesLaunch)
    }

    func testSizesStayWithinTheDocksLimits() {
        XCTAssertEqual(DockSettings(iconSize: 4).iconSize, 16)
        XCTAssertEqual(DockSettings(macDockPreferences: ["tilesize": 512]).iconSize, 128)
    }

    func testMagnificationIsTheRatioOfTheTwoSizes() {
        XCTAssertEqual(DockSettings(iconSize: 40, magnifies: true, magnifiedSize: 100).magnification, 2.5)
        XCTAssertEqual(DockSettings(iconSize: 40, magnifies: false, magnifiedSize: 100).magnification, 1)
        // A magnified size below the icon size doesn't shrink icons.
        XCTAssertEqual(DockSettings(iconSize: 64, magnifies: true, magnifiedSize: 32).magnification, 1)
    }
}
