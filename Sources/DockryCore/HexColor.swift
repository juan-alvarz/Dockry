import Foundation

/// Colors as "#RRGGBB" strings, the way profiles.json stores them.
public enum HexColor {
    /// The red, green and blue components (0–1), or nil if it isn't a color like "#3563E9".
    public static func components(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        guard let normalized = normalized(hex), let value = UInt32(normalized.dropFirst(), radix: 16) else { return nil }
        return (Double(value >> 16 & 0xFF) / 255, Double(value >> 8 & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// "#RRGGBB" in upper case, from that with or without the "#" or in lower case.
    public static func normalized(_ hex: String) -> String? {
        let digits = hex.trimmingCharacters(in: .whitespaces).uppercased().drop { $0 == "#" }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        return "#" + digits
    }

    public static func string(red: Double, green: Double, blue: Double) -> String {
        let byte = { (component: Double) in Int((component.clamped(to: 0...1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Whether white text reads better than black on this color.
    public static func prefersLightText(_ hex: String) -> Bool {
        guard let (red, green, blue) = components(hex) else { return false }
        // Relative luminance, as WCAG defines it.
        let linear = { (c: Double) in c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance < 0.4
    }
}
