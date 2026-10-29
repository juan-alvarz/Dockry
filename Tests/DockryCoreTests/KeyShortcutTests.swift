import XCTest
@testable import DockryCore

final class KeyShortcutTests: XCTestCase {
    private let control = 0x40000

    private func hotKeys(id: String, enabled: Bool, parameters: [Int]) -> [String: Any] {
        [id: ["enabled": enabled, "value": ["parameters": parameters, "type": "standard"]]]
    }

    func testShowsModifiersInMenuOrder() {
        let shortcut = KeyShortcut(keyCode: 0x12, modifierFlags: KeyShortcut.command | KeyShortcut.control | KeyShortcut.option | 0x100, key: "1")
        XCTAssertEqual(shortcut.displayString, "⌃⌥⌘1")
        XCTAssertTrue(shortcut.isUsableGlobally)
        XCTAssertFalse(KeyShortcut(keyCode: 0x12, modifierFlags: KeyShortcut.shift, key: "1").isUsableGlobally)
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
