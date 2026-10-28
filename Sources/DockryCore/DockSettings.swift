import Foundation

/// The screen edge the dock sits on.
public enum DockPosition: String, CaseIterable {
    case left, bottom, right

    public var isVertical: Bool { self != .bottom }
}

/// How the dock looks and behaves: the same choices the macOS Dock offers.
public struct DockSettings: Equatable {
    /// The Dock's own limits for its icon size, in points.
    public static let sizeRange: ClosedRange<Double> = 16...128

    public var position: DockPosition
    public var iconSize: Double
    public var magnifies: Bool
    /// Size of the icon under the pointer while magnifying.
    public var magnifiedSize: Double
    public var autohides: Bool
    public var showsIndicators: Bool
    public var animatesLaunch: Bool

    public init(
        position: DockPosition = .bottom,
        iconSize: Double = 48,
        magnifies: Bool = false,
        magnifiedSize: Double = 80,
        autohides: Bool = false,
        showsIndicators: Bool = true,
        animatesLaunch: Bool = true
    ) {
        self.position = position
        self.iconSize = iconSize.clamped(to: Self.sizeRange)
        self.magnifies = magnifies
        self.magnifiedSize = magnifiedSize.clamped(to: Self.sizeRange)
        self.autohides = autohides
        self.showsIndicators = showsIndicators
        self.animatesLaunch = animatesLaunch
    }

    /// How many times bigger the icon under the pointer gets; 1 when not magnifying.
    public var magnification: Double {
        magnifies ? max(magnifiedSize, iconSize) / iconSize : 1
    }

    /// The macOS Dock's settings, from its preferences (the com.apple.dock domain). Keys that
    /// aren't set get the Dock's defaults.
    public init(macDockPreferences values: [String: Any]) {
        self.init(
            position: (values["orientation"] as? String).flatMap(DockPosition.init(rawValue:)) ?? .bottom,
            iconSize: Self.number(values["tilesize"]) ?? 48,
            magnifies: Self.bool(values["magnification"]) ?? false,
            magnifiedSize: Self.number(values["largesize"]) ?? 128,
            autohides: Self.bool(values["autohide"]) ?? false,
            showsIndicators: Self.bool(values["show-process-indicators"]) ?? true,
            animatesLaunch: Self.bool(values["launchanim"]) ?? true)
    }

    /// The preference keys `init(macDockPreferences:)` reads.
    public static let macDockPreferenceKeys = [
        "orientation", "tilesize", "magnification", "largesize", "autohide",
        "show-process-indicators", "launchanim",
    ]

    // Preferences hold numbers as NSNumber, which a plain `as? Double` or `as? Bool` doesn't
    // always unwrap the same way on every platform.
    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double: value
        case let value as Int: Double(value)
        case let value as NSNumber: value.doubleValue
        default: nil
        }
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool: value
        case let value as Int: value != 0
        case let value as NSNumber: value.boolValue
        default: nil
        }
    }
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
