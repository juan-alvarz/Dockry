public struct KeyShortcut: Equatable {
    /// macOS virtual key code (kVK_*).
    public let keyCode: UInt16
    /// Modifier flags with the same raw values as CGEventFlags / NSEvent.ModifierFlags.
    public let modifierFlags: UInt64

    public init(keyCode: UInt16, modifierFlags: UInt64) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    /// Virtual key codes of the 1–9 keys (kVK_ANSI_1…kVK_ANSI_9), which aren't sequential.
    private static let digitKeyCodes: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]

    public static func keyCode(forDigit digit: Int) -> UInt16? {
        (1...9).contains(digit) ? digitKeyCodes[digit - 1] : nil
    }

    /// The "Switch to Desktop N" shortcut from the `AppleSymbolicHotKeys` dictionary of the
    /// com.apple.symbolichotkeys preferences. Nil when it's missing or turned off, which is
    /// the macOS default until the user enables it in Keyboard Shortcuts › Mission Control.
    public static func switchToDesktop(_ desktop: Int, in symbolicHotKeys: [String: Any]) -> KeyShortcut? {
        // Desktops 1–9 have the symbolic hot key IDs 118–126.
        guard (1...9).contains(desktop),
              let entry = symbolicHotKeys[String(117 + desktop)] as? [String: Any],
              entry["enabled"] as? Bool == true,
              let value = entry["value"] as? [String: Any],
              // [character, key code, modifier flags]; 65535 means "no key".
              let parameters = value["parameters"] as? [Int], parameters.count == 3,
              let keyCode = UInt16(exactly: parameters[1]), keyCode != UInt16.max,
              let modifiers = UInt64(exactly: parameters[2])
        else { return nil }
        return KeyShortcut(keyCode: keyCode, modifierFlags: modifiers)
    }
}
