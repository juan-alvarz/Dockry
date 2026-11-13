import XCTest
@testable import DockryCore

final class WindowParkingTests: XCTestCase {
    private let laptop = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 800, height: 600)

    func testOnOneScreenAWindowParksUnderItsBottomRightCornerWithOnePointShowing() {
        let spot = WindowParking.spot(for: size, screens: [laptop])
        XCTAssertEqual(spot, CGRect(x: 1439, y: -599, width: 800, height: 600))
        XCTAssertTrue(WindowParking.isParked(spot!, screens: [laptop]))
    }

    func testWithAHigherScreenOnTheRightTheSpotIsStillOnAScreen() {
        // The corner of both screens together (3360, 0) is under the monitor, on no screen.
        let monitor = CGRect(x: 1440, y: 300, width: 1920, height: 1080)
        let screens = [laptop, monitor]
        let spot = WindowParking.spot(for: size, screens: screens)!
        XCTAssertEqual(spot, CGRect(x: 3359, y: -299, width: 800, height: 600))
        XCTAssertTrue(WindowParking.isParked(spot, screens: screens))
        XCTAssertTrue(screens.contains { $0.intersects(spot) })
    }

    func testWithAScreenBelowTheWindowParksUnderThatOne() {
        // Under the laptop's right corner is the lower monitor, where it would show whole.
        let below = CGRect(x: 1000, y: -1080, width: 1920, height: 1080)
        let screens = [laptop, below]
        let spot = WindowParking.spot(for: size, screens: screens)!
        XCTAssertTrue(WindowParking.isParked(spot, screens: screens))
        XCTAssertTrue(screens.contains { $0.intersects(spot) })
    }

    func testAWindowOnScreenIsNotParked() {
        XCTAssertFalse(WindowParking.isParked(CGRect(x: 100, y: 100, width: 800, height: 600), screens: [laptop]))
    }

    func testAWindowComesBackWhereItWas() {
        let home = CGRect(x: 100, y: 100, width: 800, height: 600)
        XCTAssertEqual(WindowParking.home(home, screens: [laptop]), home)
    }

    func testAWindowWhoseScreenWasUnpluggedComesBackToTheMiddleOfTheFirstScreen() {
        let onTheMonitor = CGRect(x: 2000, y: 400, width: 800, height: 600)
        XCTAssertEqual(WindowParking.home(onTheMonitor, screens: [laptop]), CGRect(x: 320, y: 150, width: 800, height: 600))
    }

    func testAWindowTallerThanTheScreenKeepsItsTitleBarOnIt() {
        let tall = CGRect(x: 5000, y: 0, width: 800, height: 1200)
        XCTAssertEqual(WindowParking.home(tall, screens: [laptop]).maxY, laptop.maxY)
    }
}
