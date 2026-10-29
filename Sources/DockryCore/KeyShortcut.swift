public struct KeyShortcut: Hashable, Codable {
    /// macOS virtual key code (kVK_*).
    public let keyCode: UInt16
    /// Modifier flags with the same raw values as CGEventFlags / NSEvent.ModifierFlags.
    public let modifierFlags: UInt64
    /// The key as the keyboard showed it when the shortcut was recorded, like "1" or "Space".
    public var key: String?

    public static let control: UInt64 = 1 << 18
    public static let option: UInt64 = 1 << 19
    public static let shift: UInt64 = 1 << 17
    public static let command: UInt64 = 1 << 20

    public init(keyCode: UInt16, modifierFlags: UInt64, key: String? = nil) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.key = key
    }

    /// Only ⌃⌥⇧⌘ count, as in a global shortcut.
    public var modifiers: UInt64 { modifierFlags & (Self.control | Self.option | Self.shift | Self.command) }

    /// A global shortcut needs ⌃, ⌥ or ⌘; with only ⇧ (or nothing) it would take over typing.
    public var isUsableGlobally: Bool { modifiers & (Self.control | Self.option | Self.command) != 0 }

    /// Like a menu shows it: "⌃⌥1".
    public var displayString: String {
        let symbols: [(UInt64, String)] = [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
        return symbols.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + (key ?? "Key \(keyCode)")
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
