import XCTest
@testable import DockryCore

final class KeyShortcutTests: XCTestCase {
    private let control = 0x40000

    private func hotKeys(id: String, enabled: Bool, parameters: [Int]) -> [String: Any] {
        [id: ["enabled": enabled, "value": ["parameters": parameters, "type": "standard"]]]
    }

    func testDigitKeyCodes() {
        XCTAssertEqual(KeyShortcut.keyCode(forDigit: 1), 0x12)
        XCTAssertEqual(KeyShortcut.keyCode(forDigit: 5), 0x17)
        XCTAssertEqual(KeyShortcut.keyCode(forDigit: 9), 0x19)
        XCTAssertNil(KeyShortcut.keyCode(forDigit: 0))
        XCTAssertNil(KeyShortcut.keyCode(forDigit: 10))
    }

    func testReadsAnEnabledDesktopShortcut() {
        // Desktop 2 is symbolic hot key 119, ⌃2 by default.
        let shortcut = KeyShortcut.switchToDesktop(2, in: hotKeys(id: "119", enabled: true, parameters: [50, 19, control]))
        XCTAssertEqual(shortcut, KeyShortcut(keyCode: 19, modifierFlags: UInt64(control)))
    }

    func testDisabledOrMissingShortcutsAreNil() {
        XCTAssertNil(KeyShortcut.switchToDesktop(2, in: hotKeys(id: "119", enabled: false, parameters: [50, 19, control])))
        XCTAssertNil(KeyShortcut.switchToDesktop(2, in: [:]))
    }

    func testShortcutWithoutAKeyIsNil() {
        XCTAssertNil(KeyShortcut.switchToDesktop(1, in: hotKeys(id: "118", enabled: true, parameters: [65535, 65535, 0])))
    }

    func testDesktopsOutsideOneToNineAreNil() {
        XCTAssertNil(KeyShortcut.switchToDesktop(0, in: hotKeys(id: "117", enabled: true, parameters: [48, 29, control])))
        XCTAssertNil(KeyShortcut.switchToDesktop(10, in: hotKeys(id: "127", enabled: true, parameters: [48, 29, control])))
    }
}
